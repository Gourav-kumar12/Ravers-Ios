//
//  RootView.swift
//  Raverse-ios
//
//  The app's traffic cop. Watches auth state and shows EITHER the auth flow
//  (Email → OTP → verified Supabase session) OR the main tab bar.
//
//  Owns the single AuthViewModel and injects it into the environment, so every
//  child screen reads/drives the same auth state. Launched from @main.
//

import SwiftUI

struct RootView: View {
    @State private var auth = AuthViewModel()

    var body: some View {
        Group {
            switch auth.step {
            case .launching:
                LoadingScreen()

            case .email, .code:
                EmailLoginView()

            case .signedIn:
                if let userID = auth.userID {
                    AuthenticatedAppView(userID: userID)
                        .id(userID)
                }
            }
        }
        .environment(auth)
        .task { await auth.start() }
        .alert("You're signed in", isPresented: $auth.showLoginSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your email is verified and your profile has been saved.")
        }
    }
}

private struct AuthenticatedAppView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var vault: VaultStore
    @State private var wishlist = WishlistStore()
    @State private var matches: MatchStore
    @State private var payments: PaymentMethodStore
    @State private var profile = ProfileViewModel()

    init(userID: UUID) {
        _vault = State(initialValue: VaultStore(userID: userID))
        _matches = State(initialValue: MatchStore(userID: userID))
        _payments = State(initialValue: PaymentMethodStore(userID: userID))
    }

    var body: some View {
        MainTabView()
            .environment(vault)
            .environment(wishlist)
            .environment(matches)
            .environment(profile)
            .environment(payments)
            .task { await profile.load() }
            .task { await vault.load() }
            .task { await matches.load() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await vault.load() }
                    Task { await matches.load() }
                }
            }
    }
}

#Preview {
    RootView()
}
