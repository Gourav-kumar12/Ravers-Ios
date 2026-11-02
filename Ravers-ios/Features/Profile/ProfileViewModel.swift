import SwiftUI

@Observable
final class ProfileViewModel {
    var profile: UserProfile?
    var upcomingPasses: [UpcomingPass] = []
    var beenThere: [PastEvent] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    // MARK: - Privacy and notification settings
    var ghostMode = true
    var showMyArea = true
    var shareAttendance = true
    var notifyDrops = true
    var notifyPartyAlerts = true
    var notifySyncRequests = true

    private let service: ProfileService
    private var hasLoaded = false
    private var settingsSaveTask: Task<Void, Never>?

    init(service: ProfileService = ProfileService()) {
        self.service = service
    }

    let personalityOptions = [
        "Night Owl", "Festival Head", "Underground", "Social Butterfly",
        "Melody Chaser", "Bass Junkie", "VIP Regular"
    ]
    let genreOptions = [
        "Techno", "Melodic Techno", "House", "Deep House", "Tech House",
        "Progressive", "Trance", "Drum & Bass", "Afro House", "Minimal",
        "Hardgroove", "Disco", "Hip-Hop", "Bollywood"
    ]
    let artistOptions = [
        "Amelie Lens", "Tale Of Us", "ARKA", "Colyn", "Astrix", "Vini Vici",
        "Peggy Gou", "Ritviz", "Nucleya", "Sub Focus", "Nolsie", "NULLPOINT",
        "Mirage Skin", "Ana Verma", "BPRDJ", "Ricardo Villalobos"
    ]
    let venueOptions = ["Warehouse", "Open-Air", "Rooftop", "Forest", "Bunker", "Afterhours"]

    let menuItems: [ProfileMenuItem] = [
        ProfileMenuItem(icon: "ticket", title: "Your Passes", subtitle: "Event tickets & entries", badge: nil),
        ProfileMenuItem(icon: "gift", title: "Rewards", subtitle: "Unlock perks & drops", badge: "2 New"),
        ProfileMenuItem(icon: "questionmark.circle", title: "Help & Support", subtitle: "Commonly asked queries & chat", badge: nil),
        ProfileMenuItem(icon: "gearshape", title: "Accounts & Settings", subtitle: "Payments, permissions & more", badge: nil)
    ]

    var settings: ProfilePreferences {
        ProfilePreferences(
            ghostMode: ghostMode,
            showMyArea: showMyArea,
            shareAttendance: shareAttendance,
            notifyDrops: notifyDrops,
            notifyPartyAlerts: notifyPartyAlerts,
            notifySyncRequests: notifySyncRequests
        )
    }

    func load(forceRefresh: Bool = false) async {
        guard (forceRefresh || !hasLoaded), !isLoading else { return }
        isLoading = true
        errorMessage = nil
        if forceRefresh { profile = nil }
        defer { isLoading = false }
        do {
            let (loadedProfile, loadedSettings) = try await service.fetchMyProfile()
            profile = loadedProfile
            apply(loadedSettings)
            hasLoaded = true
        } catch ProfileServiceError.notAuthenticated {
            // The root view also calls load before login; surface the missing
            // session once the profile screen is actually presented.
            errorMessage = "Your session has ended. Sign in with your email again to sync your profile."
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func save(_ draft: UserProfile) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            profile = try await service.save(profile: draft, settings: settings)
            hasLoaded = true
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    func saveHostedRave(_ draft: UserProfile) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await service.saveHostedRave(draft)
            profile = draft
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    /// Debounce changes made by the privacy and notification toggles so quick
    /// taps result in one write with the latest values.
    func scheduleSettingsSave() {
        guard hasLoaded else { return }
        settingsSaveTask?.cancel()
        settingsSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            do {
                guard let profile = self.profile else { return }
                try await self.service.updateSettings(self.settings, profile: profile)
            } catch {
                self.errorMessage = Self.message(for: error)
            }
        }
    }

    private func apply(_ settings: ProfilePreferences) {
        ghostMode = settings.ghostMode
        showMyArea = settings.showMyArea
        shareAttendance = settings.shareAttendance
        notifyDrops = settings.notifyDrops
        notifyPartyAlerts = settings.notifyPartyAlerts
        notifySyncRequests = settings.notifySyncRequests
    }

    private static func message(for error: Error) -> String {
        let text = error.localizedDescription.lowercased()
        if text.contains("duplicate key") || text.contains("profiles_handle_key") || text.contains("profiles_handle_unique") {
            return "That handle is already taken. Try another one."
        }
        if text.contains("row-level security") || text.contains("permission denied") || text.contains("unauthorized") {
            return "Supabase blocked this profile request. Check the profile table policies and sign-in session."
        }
        if (error as? URLError) != nil {
            return "No internet connection. Your changes are still on this screen; try saving again."
        }
        return error.localizedDescription
    }
}

struct UpcomingPass: Identifiable, Hashable {
    let id = UUID()
    let eventName: String
    let dateText: String
    let tier: String
    let imageName: String
    let code: String
}

struct PastEvent: Identifiable, Hashable {
    let id = UUID()
    let imageName: String
    let name: String
}

struct ProfileMenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String?
    let badge: String?
}
