//
//  MainTabView.swift
//  Raverse-ios
//


import SwiftUI

private struct ShowVaultPassesKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var showVaultPasses: (() -> Void)? {
        get { self[ShowVaultPassesKey.self] }
        set { self[ShowVaultPassesKey.self] = newValue }
    }
}

struct MainTabView: View {
    @Environment(VaultStore.self) private var vault
   
    @State private var selection = Tab.home
    @State private var requestedVaultTab: VaultView.VaultTab?

    private enum Tab: Hashable { case partner, party, home, vault, profile }

    var body: some View {
        TabView(selection: $selection) {
            // Partner (Rave Sync) is gated behind a purchase or a booked pass;
          
            Group {
                if vault.hasPartnerAccess {
                    PartnerView(goToProfile: { selection = .profile })
                } else {
                    PartnerLockedView(
                        goToStore: { selection = .home },
                        goToParties: { selection = .party }
                    )
                }
            }
            .tabItem { Label("Partner", systemImage: "person.2") }
            .tag(Tab.partner)

            NavigationStack {
                PartyView()
            }
            .tabItem { Label("Party", systemImage: "waveform") }
            .tag(Tab.party)

            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            NavigationStack {
                VaultView(requestedTab: $requestedVaultTab)
            }
            .tabItem { Label("Vault", systemImage: "lock.square") }
            .badge(vault.count)
            .tag(Tab.vault)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag(Tab.profile)
        }
        .tint(.rvRed)
        .environment(\.showVaultPasses, {
            requestedVaultTab = .passes
            selection = .vault
        })
    }
}

#Preview {
    MainTabView()
        .environment(VaultStore())
        .environment(WishlistStore())
        .environment(MatchStore())
        .environment(ProfileViewModel())
        .environment(PaymentMethodStore())
}
