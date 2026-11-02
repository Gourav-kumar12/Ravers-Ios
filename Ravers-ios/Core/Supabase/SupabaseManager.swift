
import Foundation
import Supabase

final class SupabaseManager {
    /// Shared singleton — call `SupabaseManager.shared` from anywhere.
    static let shared = SupabaseManager()

    private init() {}

    private let lock = NSLock()
    private var cachedClient: SupabaseClient?

    /// Returns the single shared client, creating it on first use, so bad/missing
    /// config can be shown by the calling screen instead of terminating the app.
    func makeClient() throws -> SupabaseClient {
        lock.lock()
        defer { lock.unlock() }

        if let cachedClient { return cachedClient }

        let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""

        guard !url.isEmpty,
              let supabaseURL = URL(string: url),
              supabaseURL.scheme == "https",
              supabaseURL.host != nil,
              !anonKey.isEmpty else {
            throw SupabaseConfigurationError.missingOrInvalidValues
        }

        // The SDK stores the session in the Keychain and refreshes tokens itself.
        // emitLocalSessionAsInitialSession: a returning user is signed in
        // immediately from the Keychain (even offline); if the refresh token is
        // no longer valid the SDK follows up with a `.signedOut` event.
        let client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
        cachedClient = client
        return client
    }
}

private enum SupabaseConfigurationError: LocalizedError {
    case missingOrInvalidValues

    var errorDescription: String? {
        "Supabase URL or publishable key is missing or invalid in the app's Info.plist."
    }
}
