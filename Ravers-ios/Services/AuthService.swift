import Foundation
import Supabase

/// The UUID always belongs to a real Supabase session, never to the entered email.
enum AuthState: Equatable {
    case signedIn(userID: UUID)
    case signedOut
    case failed(message: String)
}

@MainActor
protocol AuthServicing {
    func sendOTP(to email: String) async throws
    func verifyOTP(email: String, code: String) async throws -> UUID
    func signOut() async throws
    func authStateChanges() throws -> AsyncStream<AuthState>
}

enum EmailAuthError: LocalizedError {
    case invalidCode, invalidEmail, rateLimited, deliveryUnavailable
    case emailDisabled, signupsDisabled, unverifiedSession, unavailable

    var errorDescription: String? {
        switch self {
        case .invalidCode: "This code is incorrect or expired. Try again or request a new code."
        case .invalidEmail: "Enter a valid email address."
        case .rateLimited: "Too many attempts. Wait at least a minute before trying again."
        case .deliveryUnavailable: "We couldn't send the email. Please try again later."
        case .emailDisabled: "Email sign-in is currently unavailable. Please contact support."
        case .signupsDisabled: "New registrations are currently unavailable. Please contact support."
        case .unverifiedSession: "We couldn't verify your email session. Please request a new code."
        case .unavailable: "Sign-in is temporarily unavailable. Please try again."
        }
    }
}

@MainActor
final class AuthService: AuthServicing {
    /// Supabase generates and emails the code using the hosted {{ .Token }} template.
    func sendOTP(to email: String) async throws {
        do {
            try await SupabaseManager.shared.makeClient().auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )
        } catch {
            throw Self.mapped(error)
        }
    }

    func verifyOTP(email: String, code: String) async throws -> UUID {
        do {
            let client = try SupabaseManager.shared.makeClient()
            let response = try await client.auth.verifyOTP(email: email, token: code, type: .email)
            guard let session = response.session,
                  Self.isVerifiedEmailUser(session.user),
                  session.user.email?.lowercased() == email.lowercased() else {
                try? await client.auth.signOut(scope: .local)
                throw EmailAuthError.unverifiedSession
            }
            try await ProfileService().prepareProfile(for: session.user)
            return session.user.id
        } catch {
            throw Self.mapped(error)
        }
    }

    func signOut() async throws {
        try await SupabaseManager.shared.makeClient().auth.signOut(scope: .local)
    }

    func authStateChanges() throws -> AsyncStream<AuthState> {
        let client = try SupabaseManager.shared.makeClient().auth
        return AsyncStream { continuation in
            let task = Task {
                for await (event, session) in client.authStateChanges {
                    guard !Task.isCancelled else { break }
                    switch event {
                    case .initialSession, .signedIn, .signedOut,
                         .tokenRefreshed, .userUpdated, .userDeleted:
                        guard let session, Self.isVerifiedEmailUser(session.user) else {
                            continuation.yield(.signedOut)
                            continue
                        }
                        do {
                            // Also repair interrupted saves before restoring Home.
                            try await ProfileService().prepareProfile(for: session.user)
                            guard !Task.isCancelled else { break }
                            // A sign-out may have happened while the save was awaiting.
                            if client.currentUser?.id == session.user.id {
                                continuation.yield(.signedIn(userID: session.user.id))
                            }
                        } catch {
                            if client.currentUser?.id == session.user.id {
                                continuation.yield(.failed(message: error.localizedDescription))
                            }
                        }
                    default:
                        continue
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    nonisolated static func isVerifiedEmailUser(_ user: User) -> Bool {
        !user.isAnonymous && user.emailConfirmedAt != nil && !(user.email ?? "").isEmpty
    }

    private static func mapped(_ error: Error) -> Error {
        #if DEBUG
        if let networkError = error as? URLError {
            // Log only the code and hostname; never the email, OTP, key or request body.
            let host = (networkError.userInfo[NSURLErrorFailingURLErrorKey] as? URL)?.host ?? "unknown"
            print("[AuthService] Network error \(networkError.code.rawValue), host: \(host)")
        }
        #endif
        guard let authError = error as? AuthError else { return error }
        switch authError.errorCode.rawValue {
        case "otp_expired", "invalid_credentials": return EmailAuthError.invalidCode
        case "email_address_invalid", "email_address_not_valid", "validation_failed": return EmailAuthError.invalidEmail
        case "email_address_not_authorized", "unexpected_failure", "hook_timeout", "hook_timeout_after_retry":
            return EmailAuthError.deliveryUnavailable
        case "email_provider_disabled", "provider_disabled", "otp_disabled": return EmailAuthError.emailDisabled
        case "signup_disabled": return EmailAuthError.signupsDisabled
        case "over_request_rate_limit", "over_email_send_rate_limit", "over_sent_security_code_rate_limit": return EmailAuthError.rateLimited
        default:
            if case .api(_, _, _, let response) = authError, response.statusCode == 429 {
                return EmailAuthError.rateLimited
            }
            return EmailAuthError.unavailable
        }
    }
}
