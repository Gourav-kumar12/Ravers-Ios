

import SwiftUI

@Observable
final class ProfileViewModel {
    var profile: UserProfile?
    /// Tickets the user is holding for upcoming events (shown in UPCOMING).
    var upcomingPasses: [UpcomingPass] = []
    /// Past events the user has attended (shown in BEEN THERE).
    var beenThere: [PastEvent] = []

    // MARK: - Privacy toggles (Privacy dropdown)
    var ghostMode = true
    var showMyArea = true
    var shareAttendance = true

    // MARK: - Notification toggles (Notifications dropdown)
    var notifyDrops = true
    var notifyPartyAlerts = true
    var notifySyncRequests = true

    /// Single-select personality options shown on the Edit Profile screen.
    let personalityOptions: [String] = [
        "Night Owl", "Festival Head", "Underground", "Social Butterfly",
        "Melody Chaser", "Bass Junkie", "VIP Regular"
    ]

    /// Multi-select music-taste (genre) options shown on the Edit Profile screen.
    let genreOptions: [String] = [
        "Techno", "Melodic Techno", "House", "Deep House", "Tech House",
        "Progressive", "Trance", "Drum & Bass", "Afro House", "Minimal",
        "Hardgroove", "Disco", "Hip-Hop", "Bollywood"
    ]

    /// Multi-select venue / vibe options shown on the Edit Profile screen.
    let venueOptions: [String] = [
        "Club", "Indoor", "Home", "Open Air", "Rooftop",
        "Warehouse", "Festival", "Beach", "Lounge", "Underground"
    ]

    /// Menu rows rendered below the header, in order.
    let menuItems: [ProfileMenuItem] = [
        ProfileMenuItem(icon: "ticket", title: "Your Passes", subtitle: "Event tickets & entries", badge: nil),
        ProfileMenuItem(icon: "gift", title: "Rewards", subtitle: "Unlock perks & drops", badge: "2 New"),
        ProfileMenuItem(icon: "questionmark.circle", title: "Help & Support", subtitle: "Commonly asked queries & chat", badge: nil),
        ProfileMenuItem(icon: "gearshape", title: "Accounts & Settings", subtitle: "Payments, permissions & more", badge: nil)
    ]

    func load() async {
        // Sample profile until Supabase auth is wired in.
        if profile == nil {
            profile = UserProfile(
                id: "me",
                displayName: "REHAN MALHOTRA",
                handle: "@rehan.wav",
                email: "",
                phone: "",
                city: "HSR Layout, Bengaluru",
                memberSince: "March 2025",
                avatarName: "logo",
                personality: "Night Owl",
                genres: ["Techno", "Melodic Techno", "Drum & Bass"],
                venues: ["Club", "Warehouse", "Open Air"],
                favoriteArtists: ["Amelie Lens", "Tale Of Us", "ARKA", "Colyn"],
                partiesCount: 14,
                piecesOwned: 7,
                crewCount: 1
            )
        }

        // Sample tickets & history until Supabase is wired in.
        if upcomingPasses.isEmpty {
            upcomingPasses = [
                UpcomingPass(eventName: "Bassment 004", dateText: "Sat, 9 Aug",
                             tier: "Standard", imageName: "party-2", code: "RV70CS02XR5H2V"),
                UpcomingPass(eventName: "Void Frequency", dateText: "Sat, 8 Aug",
                             tier: "Phase 1", imageName: "party-1", code: "RV88KD10ZT4M9Q")
            ]
        }
        if beenThere.isEmpty {
            beenThere = [
                PastEvent(imageName: "party-1", name: "Warehouse 7"),
                PastEvent(imageName: "party-2", name: "The Bunker"),
                PastEvent(imageName: "party-3", name: "Skyline Terrace")
            ]
        }
    }
}

/// A ticket the user is holding for an upcoming event.
struct UpcomingPass: Identifiable, Hashable {
    let id = UUID()
    let eventName: String
    let dateText: String        // "Sat, 9 Aug"
    let tier: String            // "Standard", "Phase 1"
    let imageName: String
    let code: String            // QR payload shown at the door
}

/// A past event, shown as a photo tile in BEEN THERE.
struct PastEvent: Identifiable, Hashable {
    let id = UUID()
    let imageName: String
    let name: String
}

/// One tappable row in the account menu.
struct ProfileMenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String?
    let badge: String?
}
