import Foundation
import Testing
import Supabase
@testable import Ravers_ios

@MainActor
struct EmailLoginTests {
    @Test func sendsNormalizedEmailWithoutUnlockingHome() async {
        let service = AuthStub()
        let model = await readyModel(service)
        model.emailAddress = "  Person+Rave@Gmail.com \n"
        await model.login()
        #expect(service.sentEmails == ["person+rave@gmail.com"])
        #expect(model.pendingEmail == "person+rave@gmail.com")
        #expect(model.step == .code)
        #expect(model.userID == nil)
        #expect(!model.showLoginSuccess)
        #expect(!model.isLoading)
    }

    @Test(arguments: ["", "person", "a@@gmail.com", "a b@gmail.com", ".a@gmail.com", "a..b@gmail.com", "a@gmail", "a@-gmail.com", "a@gmail..com", "a@💌.com"])
    func invalidEmailCannotRequestCode(_ email: String) async {
        let service = AuthStub()
        let model = await readyModel(service)
        model.emailAddress = email
        await model.login()
        #expect(service.sentEmails.isEmpty)
        #expect(model.step == .email)
        #expect(model.userID == nil)
        #expect(model.errorMessage != nil)
    }

    @Test func deliveryFailureStaysOnEmailAndCanRetry() async {
        let service = AuthStub()
        service.sendError = EmailAuthError.deliveryUnavailable
        let model = await readyModel(service)
        await model.login()
        #expect(model.step == .email)
        #expect(model.pendingEmail == nil)
        #expect(model.errorMessage != nil)
        #expect(!model.showLoginSuccess)
        #expect(!model.isLoading)
        service.sendError = nil
        await model.login()
        #expect(model.step == .code)
        #expect(model.errorMessage == nil)
    }

    @Test func verifiedCodeOpensHomeWithSupabaseIdentity() async {
        let service = AuthStub()
        let model = await codeModel(service)
        // Verification is bound to the address that received the code.
        model.emailAddress = "another@gmail.com"
        await model.verifyCode()
        #expect(service.verifiedEmails == ["person@gmail.com"])
        #expect(service.verifiedCodes == ["123456"])
        #expect(model.step == .signedIn)
        #expect(model.userID == service.id)
        #expect(model.otp.isEmpty)
        #expect(model.pendingEmail == nil)
        #expect(model.showLoginSuccess)
    }

    @Test(arguments: ["", "12345", "1234567", "abcdef", "１２３４５６", "12 456"])
    func malformedCodeIsNotSubmitted(_ code: String) async {
        let service = AuthStub()
        let model = await codeModel(service)
        model.otp = code
        await model.verifyCode()
        #expect(service.verifiedCodes.isEmpty)
        #expect(model.step == .code)
        #expect(model.userID == nil)
        #expect(model.errorMessage != nil)
    }

    @Test(arguments: [false, true])
    func invalidOrOfflineVerificationDoesNotUnlockHome(_ offline: Bool) async {
        let service = AuthStub()
        service.verifyError = offline ? URLError(.notConnectedToInternet) : EmailAuthError.invalidCode
        let model = await codeModel(service)
        await model.verifyCode()
        #expect(model.step == .code)
        #expect(model.userID == nil)
        #expect(model.otp == "123456")
        #expect(model.errorMessage != nil)
        #expect(!model.showLoginSuccess)
        #expect(!model.isLoading)
        service.verifyError = nil
        await model.verifyCode()
        #expect(model.step == .signedIn)
    }

    @Test func resendCooldownSurvivesEditingAndUsesElapsedTime() async {
        let service = AuthStub()
        var date = Date(timeIntervalSince1970: 1000)
        let model = await readyModel(service, now: { date })
        await model.login()
        #expect(model.resendSecondsRemaining() == 60)
        await model.resendCode()
        #expect(service.sentEmails.count == 1)
        model.changeEmail()
        await model.login()
        #expect(service.sentEmails.count == 1)
        #expect(model.step == .code)
        date.addTimeInterval(61)
        model.otp = "123456"
        await model.resendCode()
        #expect(service.sentEmails.count == 2)
        #expect(model.otp.isEmpty)
        #expect(model.resendSecondsRemaining() == 60)
    }

    @Test func failedResendPreservesCodeAndRecipient() async {
        let service = AuthStub()
        var date = Date(timeIntervalSince1970: 1000)
        let model = await readyModel(service, now: { date })
        await model.login()
        model.otp = "123456"
        date.addTimeInterval(61)
        service.sendError = URLError(.notConnectedToInternet)
        await model.resendCode()
        #expect(model.step == .code)
        #expect(model.pendingEmail == "person@gmail.com")
        #expect(model.otp == "123456")
        #expect(model.errorMessage != nil)
        #expect(model.resendSecondsRemaining() == 0)
    }

    @Test func changingEmailClearsCodeAndUsesNewRecipient() async {
        let service = AuthStub()
        let model = await codeModel(service)
        model.changeEmail()
        #expect(model.step == .email)
        #expect(model.pendingEmail == nil)
        #expect(model.otp.isEmpty)
        model.emailAddress = "new@gmail.com"
        await model.login()
        #expect(service.sentEmails == ["person@gmail.com", "new@gmail.com"])
        #expect(model.pendingEmail == "new@gmail.com")
    }

    @Test func profileFailureClearsPendingRecipientBeforeChangingEmail() async {
        let service = AuthStub()
        let model = await codeModel(service)
        service.continuation?.yield(.failed(message: "Couldn't save the profile."))
        for _ in 0..<100 where model.step == .code { await Task.yield() }
        #expect(model.step == .email)
        #expect(model.pendingEmail == nil)
        #expect(model.otp.isEmpty)
        model.emailAddress = "new@gmail.com"
        await model.login()
        #expect(service.sentEmails == ["person@gmail.com", "new@gmail.com"])
    }

    @Test func restoresSessionAndClearsIdentityOnSignOutEvent() async {
        let service = AuthStub()
        service.initialState = .signedIn(userID: service.id)
        let model = AuthViewModel(service: service)
        await model.start()
        for _ in 0..<100 where model.step == .launching { await Task.yield() }
        #expect(model.step == .signedIn)
        #expect(model.userID == service.id)
        #expect(!model.showLoginSuccess)
        service.continuation?.yield(.signedOut)
        for _ in 0..<100 where model.step == .signedIn { await Task.yield() }
        #expect(model.step == .email)
        #expect(model.userID == nil)
    }

    @Test func signOutClearsLocalIdentityEvenWhenOffline() async {
        let service = AuthStub()
        let model = await codeModel(service)
        await model.verifyCode()
        service.signOutError = URLError(.notConnectedToInternet)
        await model.signOut()
        #expect(service.signOutCalls == 1)
        #expect(model.step == .email)
        #expect(model.userID == nil)
        #expect(model.emailAddress.isEmpty)
        #expect(model.pendingEmail == nil)
        #expect(!model.showLoginSuccess)
    }

    @Test func duplicateSendRequestsAreIgnored() async {
        let service = AuthStub()
        service.suspendSend = true
        let model = await readyModel(service)
        let request = Task { await model.login() }
        for _ in 0..<100 where service.sendContinuation == nil { await Task.yield() }
        #expect(model.isLoading)
        await model.login()
        model.changeEmail()
        #expect(service.sentEmails.count == 1)
        #expect(model.step == .email)
        service.sendContinuation?.resume()
        await request.value
        #expect(model.step == .code)
        #expect(!model.isLoading)
    }

    @Test(arguments: [URLError.Code.cannotFindHost, .dnsLookupFailed, .cannotConnectToHost,
                      .timedOut, .notConnectedToInternet, .networkConnectionLost, .secureConnectionFailed])
    func networkFailureExplainsCauseAndAllowsRetry(_ code: URLError.Code) async {
        let service = AuthStub()
        let model = await readyModel(service)
        service.sendError = URLError(code)
        await model.login()
        let expectedMessage: String
        switch code {
        case .cannotFindHost, .dnsLookupFailed:
            expectedMessage = "The sign-in server address couldn't be found. Please try again later."
        case .cannotConnectToHost:
            expectedMessage = "The sign-in server is unavailable. Please try again shortly."
        case .timedOut:
            expectedMessage = "The sign-in request timed out. Please try again."
        case .notConnectedToInternet:
            expectedMessage = "You're offline. Connect to the internet and try again."
        case .networkConnectionLost:
            expectedMessage = "The connection was interrupted. Please try again."
        default:
            expectedMessage = "A secure connection to the sign-in server couldn't be established. Please try again later."
        }
        #expect(model.errorMessage == expectedMessage)
        #expect(model.step == .email)
        #expect(model.pendingEmail == nil)
        #expect(model.userID == nil)
        #expect(!model.isLoading)
        service.sendError = nil
        await model.login()
        #expect(model.step == .code)
        #expect(model.errorMessage == nil)
    }

    @Test func authEventAndDuplicateTapsCannotOpenHomeBeforeVerificationAndSaveFinish() async {
        let service = AuthStub()
        let model = await codeModel(service)
        service.suspendVerify = true
        let request = Task { await model.verifyCode() }
        for _ in 0..<100 where service.verifyContinuation == nil { await Task.yield() }
        #expect(model.isLoading)
        await model.verifyCode()
        await model.resendCode()
        model.changeEmail()
        #expect(service.verifiedCodes.count == 1)
        service.continuation?.yield(.signedIn(userID: service.id))
        for _ in 0..<10 { await Task.yield() }
        #expect(model.step == .code)
        #expect(model.userID == nil)
        service.verifyContinuation?.resume()
        await request.value
        #expect(model.step == .signedIn)
        #expect(!model.isLoading)
    }

    @Test(arguments: [0, 1, 2, 3])
    func onlyVerifiedNonAnonymousEmailUsersCanRestoreHome(_ scenario: Int) throws {
        var json: [String: Any] = [
            "id": UUID().uuidString,
            "aud": "authenticated",
            "created_at": "2026-10-21T00:00:00Z",
            "updated_at": "2026-10-21T00:00:00Z",
            "email": scenario == 2 ? "" : "person@gmail.com",
            "is_anonymous": scenario == 0,
            "user_metadata": ["contact_email": "person@gmail.com"]
        ]
        if scenario != 1 { json["email_confirmed_at"] = "2026-10-21T00:00:00Z" }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let user = try decoder.decode(User.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(AuthService.isVerifiedEmailUser(user) == (scenario == 3))
    }

    private func readyModel(_ service: AuthStub, now: @escaping () -> Date = { Date() }) async -> AuthViewModel {
        let model = AuthViewModel(service: service, now: now)
        await model.start()
        for _ in 0..<100 where model.step == .launching { await Task.yield() }
        #expect(model.step == .email)
        model.emailAddress = "person@gmail.com"
        return model
    }

    private func codeModel(_ service: AuthStub) async -> AuthViewModel {
        let model = await readyModel(service)
        await model.login()
        #expect(model.step == .code)
        model.otp = "123456"
        return model
    }
}

@MainActor
private final class AuthStub: AuthServicing {
    let id = UUID()
    var sentEmails: [String] = []
    var verifiedEmails: [String] = []
    var verifiedCodes: [String] = []
    var signOutCalls = 0
    var sendError: Error?
    var verifyError: Error?
    var signOutError: Error?
    var initialState: AuthState = .signedOut
    var continuation: AsyncStream<AuthState>.Continuation?
    var suspendSend = false
    var suspendVerify = false
    var sendContinuation: CheckedContinuation<Void, Never>?
    var verifyContinuation: CheckedContinuation<Void, Never>?

    func sendOTP(to email: String) async throws {
        sentEmails.append(email)
        if suspendSend { await withCheckedContinuation { sendContinuation = $0 } }
        if let sendError { throw sendError }
    }

    func verifyOTP(email: String, code: String) async throws -> UUID {
        verifiedEmails.append(email)
        verifiedCodes.append(code)
        if suspendVerify { await withCheckedContinuation { verifyContinuation = $0 } }
        if let verifyError { throw verifyError }
        return id
    }

    func signOut() async throws {
        signOutCalls += 1
        if let signOutError { throw signOutError }
    }

    func authStateChanges() throws -> AsyncStream<AuthState> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(initialState)
        }
    }
}
