//
//  RootView.swift
//  Raverse-ios
//
//  The app's traffic cop. Watches auth state and shows EITHER the auth flow
//  (Welcome → Phone → OTP) OR the main tab bar. Nothing else decides this.
//
//  Owns the single AuthViewModel and injects it into the environment, so every
//  child screen reads/drives the same auth state. Launched from @main.
//

import SwiftUI

struct RootView: View {
    @State private var auth = AuthViewModel()
    @State private var vault = VaultStore()
    @State private var wishlist = WishlistStore()
    @State private var matches = MatchStore()

    var body: some View {
        Group {
            switch auth.step {
            case .phone:
                PhoneLoginView()
                // (Welcome can precede this once built)

            case .otp:
                OTPVerifyView()

            case .signedIn:
                MainTabView()
            }
        }
        .environment(auth)
        .environment(vault)
        .environment(wishlist)
        .environment(matches)
    }
}

#Preview {
    RootView()
}
