import SwiftUI

/// Home requires a verified Supabase email session and a persisted profile.
@MainActor
@Observable
final class AuthViewModel {
    enum Step: Equatable {
        case launching, email, code, signedIn
    }

    private(set) var step: Step = .launching
    var emailAddress = "" {
        didSet {
            errorMessage = nil
        }
    }
    var otp = "" {
        didSet { errorMessage = nil }
    }
    private(set) var pendingEmail: String?
    private(set) var isSendingCode = false
    private var resendDates: [String: Date] = [:]
    private let now: () -> Date
    var errorMessage: String?
    private(set) var userID: UUID?
    private(set) var isSigningIn = false
    var showLoginSuccess = false
    private var isSigningOut = false
    private let service: any AuthServicing
    private var listenTask: Task<Void, Never>?

    var isLoading: Bool { isSendingCode || isSigningIn || isSigningOut }

    init(service: (any AuthServicing)? = nil, now: @escaping () -> Date = { Date() }) {
        self.service = service ?? AuthService()
        self.now = now
    }

    isolated deinit {
        listenTask?.cancel()
    }

    func start() async {
        guard listenTask == nil else { return }
        do {
            let changes = try service.authStateChanges()
            listenTask = Task { [weak self] in
                for await state in changes {
                    guard !Task.isCancelled else { return }
                    guard let self, !self.isLoading else { continue }
                    self.apply(state)
                }
            }
        } catch {
            step = .email
            errorMessage = Self.message(for: error)
        }
    }

    private func apply(_ state: AuthState) {
        switch state {
        case .signedIn(let id):
            userID = id
            pendingEmail = nil
            otp = ""
            errorMessage = nil
            step = .signedIn
        case .failed(let message):
            showLoginSuccess = false
            userID = nil
            pendingEmail = nil
            otp = ""
            step = .email
            errorMessage = message
        case .signedOut:
            showLoginSuccess = false
            userID = nil
            if step != .code { step = .email }
        }
    }

    var normalizedEmail: String {
        emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isEmailValid: Bool {
        let email = normalizedEmail
        guard email.utf8.count <= 254 else { return false }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let local = String(parts[0]), domain = String(parts[1])
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.!#$%&'*+-/=?^_`{|}~")
        guard !local.isEmpty, local.utf8.count <= 64,
              !local.hasPrefix("."), !local.hasSuffix("."), !local.contains(".."),
              local.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        return labels.count >= 2 && labels.allSatisfy { label in
            !label.isEmpty && label.count <= 63 && !label.hasPrefix("-") && !label.hasSuffix("-")
                && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        } && labels.last!.count >= 2 && labels.last!.contains(where: \.isLetter)
    }

    var isCodeValid: Bool {
        otp.count == 6 && otp.allSatisfy { $0.isASCII && $0.isNumber }
    }

    func resendSecondsRemaining(at date: Date? = nil) -> Int {
        let email = pendingEmail ?? normalizedEmail
        guard let resendDate = resendDates[email] else { return 0 }
        return max(0, Int(ceil(resendDate.timeIntervalSince(date ?? now()))))
    }

    func login() async {
        guard step == .email, !isLoading else { return }
        guard isEmailValid else {
            errorMessage = "Enter a valid email address."
            return
        }
        // Returning to the same address preserves its cooldown and code entry.
        if resendSecondsRemaining() > 0 {
            pendingEmail = normalizedEmail
            otp = ""
            step = .code
            return
        }
        await sendCode(to: normalizedEmail)
    }

    func resendCode() async {
        guard step == .code, !isLoading, let pendingEmail,
              resendSecondsRemaining() == 0 else { return }
        await sendCode(to: pendingEmail)
    }

    private func sendCode(to email: String) async {
        errorMessage = nil
        isSendingCode = true
        defer { isSendingCode = false }
        do {
            try await service.sendOTP(to: email)
            pendingEmail = email
            otp = ""
            resendDates[email] = now().addingTimeInterval(60)
            step = .code
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func verifyCode() async {
        guard step == .code, !isLoading, let pendingEmail else { return }
        guard isCodeValid else {
            errorMessage = "Enter the six-digit code from your email."
            return
        }
        errorMessage = nil
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let id = try await service.verifyOTP(email: pendingEmail, code: otp)
            apply(.signedIn(userID: id))
            showLoginSuccess = true
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func changeEmail() {
        guard !isLoading else { return }
        pendingEmail = nil
        otp = ""
        errorMessage = nil
        step = .email
    }

    func signOut() async {
        guard !isLoading else { return }
        isSigningOut = true
        defer { isSigningOut = false }
        // The SDK clears local credentials before attempting server revocation.
        try? await service.signOut()
        userID = nil
        showLoginSuccess = false
        emailAddress = ""
        pendingEmail = nil
        otp = ""
        errorMessage = nil
        step = .email
    }

    private static func message(for error: Error) -> String {
        if let error = error as? URLError {
            switch error.code {
            case .cannotFindHost, .dnsLookupFailed:
                return "The sign-in server address couldn't be found. Please try again later."
            case .cannotConnectToHost:
                return "The sign-in server is unavailable. Please try again shortly."
            case .timedOut:
                return "The sign-in request timed out. Please try again."
            case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
                return "You're offline. Connect to the internet and try again."
            case .networkConnectionLost:
                return "The connection was interrupted. Please try again."
            case .secureConnectionFailed, .serverCertificateHasBadDate,
                 .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid, .clientCertificateRejected,
                 .clientCertificateRequired:
                return "A secure connection to the sign-in server couldn't be established. Please try again later."
            default:
                return "Couldn't reach the sign-in server. Please try again."
            }
        }
        return error.localizedDescription
    }
}
