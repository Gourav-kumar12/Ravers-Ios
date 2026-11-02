import Foundation
import Supabase
import UIKit

/// Reads and writes only the signed-in user's profile. User identity always
/// comes from the Supabase session so RLS remains the source of authorization.
final class ProfileService {
    private let bucket = "profile-images"

    private func client() throws -> SupabaseClient {
        try SupabaseManager.shared.makeClient()
    }

    /// Persist contact data under the session UUID; never look up an account by email.
    func prepareProfile(for user: User) async throws {
        let client = try client()
        guard client.auth.currentUser?.id == user.id, AuthService.isVerifiedEmailUser(user) else {
            throw ProfileServiceError.notAuthenticated
        }
        let email = user.email ?? ""
        try await client.from("profiles").upsert([
            "id": user.id.uuidString,
            "email": email,
            "phone": user.phone ?? "",
            "handle": Self.defaultHandle(for: user.id)
        ], onConflict: "id", ignoreDuplicates: true).execute()
        try await client.from("profile_preferences").upsert([
            "user_id": user.id.uuidString
        ], onConflict: "user_id", ignoreDuplicates: true).execute()
        // Older signup triggers create the row without copying the Auth email.
        // Preserve contact details the user has already edited in their profile.
        if !email.isEmpty {
            try await client.from("profiles").update(["email": email])
                .eq("id", value: user.id.uuidString)
                .eq("email", value: "")
                .execute()
        }
    }

    func fetchMyProfile() async throws -> (UserProfile, ProfilePreferences) {
        let client = try client()
        guard let user = client.auth.currentUser else {
            throw ProfileServiceError.notAuthenticated
        }
        let userID = user.id
        try await prepareProfile(for: user)

        let profileRows: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value

        let preferenceRows: [PreferencesRow] = try await client
            .from("profile_preferences")
            .select()
            .eq("user_id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value

        let photoRows: [PhotoRow] = try await client
            .from("profile_photos")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value

        let primaryPath = photoRows.first(where: { $0.position == 0 })?.storagePath
        let secondaryPath = photoRows.first(where: { $0.position == 1 })?.storagePath
        async let primaryData = download(primaryPath, client: client)
        async let secondaryData = download(secondaryPath, client: client)
        let (primaryPhoto, secondaryPhoto) = await (primaryData, secondaryData)

        let row = profileRows.first
        let prefs = preferenceRows.first
        let profile = UserProfile(
            id: userID.uuidString,
            displayName: row?.displayName ?? "",
            handle: row?.handle ?? Self.defaultHandle(for: userID),
            email: row?.email ?? "",
            phone: row?.phone ?? "",
            city: row?.city ?? "",
            memberSince: Self.memberSince(row?.createdAt),
            avatarName: "",
            primaryPhoto: primaryPhoto,
            primaryPhotoPath: primaryPath,
            secondaryPhoto: secondaryPhoto,
            secondaryPhotoPath: secondaryPath,
            isHostingRave: row?.isHostingRave ?? false,
            hostedRaveName: row?.hostedRaveName ?? "",
            hostedRaveDate: row?.hostedRaveDate ?? .now,
            hostedRaveVenue: row?.hostedRaveVenue ?? "",
            hostedRaveDetails: row?.hostedRaveDetails ?? "",
            personality: row?.personality ?? "",
            genres: prefs?.genres ?? [],
            venues: prefs?.venues ?? [],
            favoriteArtists: prefs?.favoriteArtists ?? [],
            partiesCount: 0,
            piecesOwned: 0,
            crewCount: 0
        )
        let settings = ProfilePreferences(
            ghostMode: !(row?.isDiscoverable ?? false),
            showMyArea: prefs?.showMyArea ?? true,
            shareAttendance: prefs?.shareAttendance ?? true,
            notifyDrops: prefs?.notifyDrops ?? true,
            notifyPartyAlerts: prefs?.notifyPartyAlerts ?? true,
            notifySyncRequests: prefs?.notifySyncRequests ?? true
        )
        return (profile, settings)
    }

    func save(profile: UserProfile, settings: ProfilePreferences) async throws -> UserProfile {
        let client = try client()
        guard let userID = client.auth.currentUser?.id else {
            throw ProfileServiceError.notAuthenticated
        }

        let clean = try Self.validated(profile, userID: userID)
        let currentPhotos: [PhotoRow] = try await client
            .from("profile_photos")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value

        var uploadedPaths: [String] = []
        var profileWriteCompleted = false
        var saveStage = "uploading the primary photo"
        do {
            let newPrimaryPath = try await upload(clean.primaryPhoto, userID: userID, client: client)
            if let newPrimaryPath { uploadedPaths.append(newPrimaryPath) }
            saveStage = "uploading the secondary photo"
            let newSecondaryPath = try await upload(clean.secondaryPhoto, userID: userID, client: client)
            let primaryPath = newPrimaryPath ?? clean.primaryPhotoPath
            let secondaryPath = newSecondaryPath ?? clean.secondaryPhotoPath
            if let newSecondaryPath { uploadedPaths.append(newSecondaryPath) }

            let profileRow = ProfileWriteRow(
                id: userID,
                displayName: clean.displayName,
                handle: clean.handle,
                email: clean.email,
                phone: clean.phone,
                city: clean.city,
                personality: clean.personality,
                avatarPath: primaryPath,
                isDiscoverable: !settings.ghostMode,
                isProfileComplete: !clean.displayName.isEmpty && !clean.handle.isEmpty,
                isHostingRave: clean.isHostingRave,
                hostedRaveName: clean.hostedRaveName,
                hostedRaveDate: clean.hostedRaveDate,
                hostedRaveVenue: clean.hostedRaveVenue,
                hostedRaveDetails: clean.hostedRaveDetails
            )
            saveStage = "saving profile details"
            try await client.from("profiles").upsert(profileRow).execute()
            profileWriteCompleted = true

            let preferences = PreferencesWriteRow(
                userID: userID,
                genres: clean.genres,
                venues: clean.venues,
                partyStyles: clean.venues,
                favoriteArtists: clean.favoriteArtists,
                showMyArea: settings.showMyArea,
                shareAttendance: settings.shareAttendance,
                notifyDrops: settings.notifyDrops,
                notifyPartyAlerts: settings.notifyPartyAlerts,
                notifySyncRequests: settings.notifySyncRequests
            )
            saveStage = "saving profile preferences"
            try await client.from("profile_preferences").upsert(preferences).execute()

            saveStage = "saving photo references"
            var photoRows: [PhotoWriteRow] = []
            if let primaryPath { photoRows.append(PhotoWriteRow(userID: userID, position: 0, storagePath: primaryPath)) }
            if let secondaryPath { photoRows.append(PhotoWriteRow(userID: userID, position: 1, storagePath: secondaryPath)) }
            if !photoRows.isEmpty {
                try await client.from("profile_photos").upsert(photoRows).execute()
            }
            if primaryPath == nil {
                try await client.from("profile_photos").delete()
                    .eq("user_id", value: userID.uuidString)
                    .eq("position", value: 0)
                    .execute()
            }
            if secondaryPath == nil {
                try await client.from("profile_photos").delete()
                    .eq("user_id", value: userID.uuidString)
                    .eq("position", value: 1)
                    .execute()
            }

            let retainedPaths = Set([primaryPath, secondaryPath].compactMap { $0 })
            let oldPaths = currentPhotos
                .filter { $0.position < 2 }
                .map(\.storagePath)
                .filter { !retainedPaths.contains($0) }
            if !oldPaths.isEmpty {
                _ = try? await client.storage.from(bucket).remove(paths: oldPaths)
            }

            var saved = clean
            saved.primaryPhoto = clean.primaryPhoto
            saved.secondaryPhoto = clean.secondaryPhoto
            saved.primaryPhotoPath = primaryPath
            saved.secondaryPhotoPath = secondaryPath
            return saved
        } catch {
            #if DEBUG
            // Keep the failing operation visible without logging sessions or tokens.
            print("[ProfileService] Save failed while \(saveStage): \(error.localizedDescription)")
            #endif
            // A completed profile upsert may already reference a new avatar.
            // In that case an orphaned file is safer than a broken profile image.
            if !profileWriteCompleted, !uploadedPaths.isEmpty {
                _ = try? await client.storage.from(bucket).remove(paths: uploadedPaths)
            }
            throw error
        }
    }

    func updateSettings(_ settings: ProfilePreferences, profile: UserProfile) async throws {
        let client = try client()
        guard let userID = client.auth.currentUser?.id else {
            throw ProfileServiceError.notAuthenticated
        }
        let profileVisibility = VisibilityWriteRow(isDiscoverable: !settings.ghostMode)
        try await client.from("profiles")
            .update(profileVisibility)
            .eq("id", value: userID.uuidString)
            .execute()
        let preferences = PreferencesWriteRow(
            userID: userID,
            genres: profile.genres,
            venues: profile.venues,
            partyStyles: profile.venues,
            favoriteArtists: profile.favoriteArtists,
            showMyArea: settings.showMyArea,
            shareAttendance: settings.shareAttendance,
            notifyDrops: settings.notifyDrops,
            notifyPartyAlerts: settings.notifyPartyAlerts,
            notifySyncRequests: settings.notifySyncRequests
        )
        try await client.from("profile_preferences").upsert(preferences).execute()
    }

    func saveHostedRave(_ profile: UserProfile) async throws {
        let client = try client()
        guard let userID = client.auth.currentUser?.id else {
            throw ProfileServiceError.notAuthenticated
        }
        let name = profile.hostedRaveName.trimmingCharacters(in: .whitespacesAndNewlines)
        let venue = profile.hostedRaveVenue.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = profile.hostedRaveDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...80).contains(name.count), (2...120).contains(venue.count), details.count <= 1000 else {
            throw ProfileServiceError.invalidField("Enter a rave name and venue. Details can be up to 1,000 characters.")
        }
        guard profile.hostedRaveDate > .now else {
            throw ProfileServiceError.invalidField("Choose a future date and time for the rave.")
        }
        let row = HostedRaveWriteRow(
            isHostingRave: true,
            name: name,
            date: profile.hostedRaveDate,
            venue: venue,
            details: details
        )
        try await client.from("profiles")
            .update(row)
            .eq("id", value: userID.uuidString)
            .execute()
    }

    private func download(_ path: String?, client: SupabaseClient) async -> Data? {
        guard let path else { return nil }
        return try? await client.storage.from(bucket).download(path: path)
    }

    private func upload(
        _ data: Data?,
        userID: UUID,
        client: SupabaseClient
    ) async throws -> String? {
        guard let data else { return nil }
        guard data.count <= 15_000_000,
              let image = UIImage(data: data),
              image.size.width > 0,
              image.size.height > 0 else {
            throw ProfileServiceError.invalidImage
        }
        let maxDimension: CGFloat = 1600
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let jpeg = renderer.jpegData(withCompressionQuality: 0.82) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        // Storage policies compare this folder with auth.uid()::text (lowercase).
        let path = "\(userID.uuidString.lowercased())/\(UUID().uuidString).jpg"
        try await client.storage.from(bucket).upload(
            path,
            data: jpeg,
            options: FileOptions(contentType: "image/jpeg", upsert: false)
        )
        return path
    }

    private static func validated(_ profile: UserProfile, userID: UUID) throws -> UserProfile {
        var result = profile
        result.displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        result.handle = profile.handle.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
        result.email = profile.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        result.phone = profile.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        result.city = profile.city.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !result.displayName.isEmpty, result.displayName.count <= 80 else {
            throw ProfileServiceError.invalidField("Display name is required and must be 80 characters or fewer.")
        }
        guard (3...24).contains(result.handle.count), result.handle.range(of: "^[a-z0-9._]+$", options: .regularExpression) != nil else {
            throw ProfileServiceError.invalidField("Handle must be 3–24 characters using letters, numbers, dots, or underscores.")
        }
        guard result.email.isEmpty || (result.email.count <= 254 && result.email.range(of: "^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$", options: [.regularExpression, .caseInsensitive]) != nil) else {
            throw ProfileServiceError.invalidField("Enter a valid email address or leave it blank.")
        }
        let phoneDigits = result.phone.filter(\.isNumber).count
        let phoneCharactersAreValid = result.phone.allSatisfy { $0.isNumber || "+- ()".contains($0) }
        guard (result.phone.isEmpty || ((7...15).contains(phoneDigits) && phoneCharactersAreValid)), result.city.count <= 100 else {
            throw ProfileServiceError.invalidField("Check the phone number and city fields.")
        }
        result.id = userID.uuidString
        result.genres = cleanList(result.genres)
        result.venues = cleanList(result.venues)
        result.favoriteArtists = cleanList(result.favoriteArtists)
        return result
    }

    private static func cleanList(_ values: [String]) -> [String] {
        Array(Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && $0.count <= 60 })).sorted()
    }

    private static func defaultHandle(for id: UUID) -> String {
        "raver_" + id.uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
    }

    private static func memberSince(_ date: Date?) -> String {
        guard let date else { return "New member" }
        return date.formatted(.dateTime.month(.wide).year())
    }
}

struct ProfilePreferences: Equatable {
    var ghostMode: Bool
    var showMyArea: Bool
    var shareAttendance: Bool
    var notifyDrops: Bool
    var notifyPartyAlerts: Bool
    var notifySyncRequests: Bool
}

private struct ProfileRow: Decodable {
    let displayName: String?
    let handle: String?
    let email: String?
    let phone: String?
    let city: String?
    let personality: String?
    let createdAt: Date?
    let isDiscoverable: Bool?
    let isHostingRave: Bool?
    let hostedRaveName: String?
    let hostedRaveDate: Date?
    let hostedRaveVenue: String?
    let hostedRaveDetails: String?
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name", handle, email, phone, city, personality
        case createdAt = "created_at", isDiscoverable = "is_discoverable"
        case isHostingRave = "is_hosting_rave", hostedRaveName = "hosted_rave_name"
        case hostedRaveDate = "hosted_rave_date", hostedRaveVenue = "hosted_rave_venue"
        case hostedRaveDetails = "hosted_rave_details"
    }
}

private struct ProfileWriteRow: Encodable {
    let id: UUID
    let displayName: String
    let handle: String
    let email: String
    let phone: String
    let city: String
    let personality: String
    let avatarPath: String?
    let isDiscoverable: Bool
    let isProfileComplete: Bool
    let isHostingRave: Bool
    let hostedRaveName: String
    let hostedRaveDate: Date
    let hostedRaveVenue: String
    let hostedRaveDetails: String
    enum CodingKeys: String, CodingKey {
        case id, displayName = "display_name", handle, email, phone, city, personality
        case avatarPath = "avatar_path", isDiscoverable = "is_discoverable", isProfileComplete = "is_profile_complete"
        case isHostingRave = "is_hosting_rave", hostedRaveName = "hosted_rave_name"
        case hostedRaveDate = "hosted_rave_date", hostedRaveVenue = "hosted_rave_venue"
        case hostedRaveDetails = "hosted_rave_details"
    }
}

private struct HostedRaveWriteRow: Encodable {
    let isHostingRave: Bool
    let name: String
    let date: Date
    let venue: String
    let details: String
    enum CodingKeys: String, CodingKey {
        case isHostingRave = "is_hosting_rave", name = "hosted_rave_name"
        case date = "hosted_rave_date", venue = "hosted_rave_venue"
        case details = "hosted_rave_details"
    }
}

private struct VisibilityWriteRow: Encodable {
    let isDiscoverable: Bool
    enum CodingKeys: String, CodingKey { case isDiscoverable = "is_discoverable" }
}

private struct PreferencesRow: Decodable {
    let genres: [String]?
    let venues: [String]?
    let favoriteArtists: [String]?
    let showMyArea: Bool?
    let shareAttendance: Bool?
    let notifyDrops: Bool?
    let notifyPartyAlerts: Bool?
    let notifySyncRequests: Bool?
    enum CodingKeys: String, CodingKey {
        case genres, venues, favoriteArtists = "favorite_artists", showMyArea = "show_my_area"
        case shareAttendance = "share_attendance", notifyDrops = "notify_drops"
        case notifyPartyAlerts = "notify_party_alerts", notifySyncRequests = "notify_sync_requests"
    }
}

private struct PreferencesWriteRow: Encodable {
    let userID: UUID
    let genres: [String]
    let venues: [String]
    let partyStyles: [String]
    let favoriteArtists: [String]
    let showMyArea: Bool
    let shareAttendance: Bool
    let notifyDrops: Bool
    let notifyPartyAlerts: Bool
    let notifySyncRequests: Bool
    enum CodingKeys: String, CodingKey {
        case userID = "user_id", genres, venues, partyStyles = "party_styles"
        case favoriteArtists = "favorite_artists", showMyArea = "show_my_area"
        case shareAttendance = "share_attendance", notifyDrops = "notify_drops"
        case notifyPartyAlerts = "notify_party_alerts", notifySyncRequests = "notify_sync_requests"
    }
}

private struct PhotoRow: Decodable {
    let position: Int
    let storagePath: String
    enum CodingKeys: String, CodingKey { case position, storagePath = "storage_path" }
}

private struct PhotoWriteRow: Encodable {
    let userID: UUID
    let position: Int
    let storagePath: String
    enum CodingKeys: String, CodingKey { case userID = "user_id", position, storagePath = "storage_path" }
}

enum ProfileServiceError: LocalizedError {
    case notAuthenticated
    case invalidImage
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Your Supabase session is unavailable. Sign in again, then retry."
        case .invalidImage:
            return "One of the selected photos could not be read. Choose a different image."
        case .invalidField(let message): return message
        }
    }
}
