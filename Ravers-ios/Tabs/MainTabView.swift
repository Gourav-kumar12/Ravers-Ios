//
//  MainTabView.swift
//  Raverse-ios
//


import SwiftUI

struct MainTabView: View {
    @Environment(VaultStore.self) private var vault
   
    @State private var selection = Tab.partner

    private enum Tab: Hashable { case partner, party, home, vault, profile }

    var body: some View {
        TabView(selection: $selection) {
            // Partner (Rave Sync) is gated behind a purchase or a booked pass;
          
            Group {
                if vault.hasPartnerAccess {
                    PartnerView()
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
                VaultView()
            }
            .tabItem { Label("Vault", systemImage: "lock.square") }
            .badge(vault.count)
            .tag(Tab.vault)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag(Tab.profile)
        }
        .tint(.rvRed)
    }
}

#Preview {
    MainTabView()
        .environment(VaultStore())
        .environment(WishlistStore())
        .environment(MatchStore())
}
