//
//  SupabaseManager.swift
//  Raverse-ios
//
//  The single shared entry point to Supabase for the whole app.
//
//  ⚠️ This is a STUB for now — it does NOT import the Supabase SDK yet, so the
//  project keeps compiling before we add the package. Once `supabase-swift` is
//  added via Swift Package Manager, uncomment the SDK code below and delete the
//  placeholder.
//

import Foundation

// import Supabase   // ← uncomment after adding the supabase-swift package

final class SupabaseManager {
    /// Shared singleton — call `SupabaseManager.shared` from anywhere.
    static let shared = SupabaseManager()

    // Reads keys from Secrets.xcconfig via Info.plist (never hard-code them).
    // private let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    // private let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""

    // let client: SupabaseClient

    private init() {
        // client = SupabaseClient(
        //     supabaseURL: URL(string: url)!,
        //     supabaseKey: anonKey
        // )
    }
}
