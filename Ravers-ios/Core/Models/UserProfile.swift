//
//  UserProfile.swift
//  Raverse-ios
//
//  The signed-in user's profile (Profile tab).
//

import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    var id: String
    var displayName: String     // "REHAN MALHOTRA"
    var handle: String          // "@rehan.wav"
    var email: String           // "rehan@raverse.app"
    var phone: String           // "+91 98765 43210"
    var city: String
    var memberSince: String     // "March 2025"
    var avatarName: String
    /// Primary photo (JPEG data). When set, it's used as the profile avatar.
    var primaryPhoto: Data? = nil
    var primaryPhotoPath: String? = nil
    /// Secondary photo (JPEG data). Both photos must be set to appear in discovery.
    var secondaryPhoto: Data? = nil
    var secondaryPhotoPath: String? = nil
    /// Host-submitted party details, shown in the Party feed when sharing is enabled.
    var isHostingRave: Bool = false
    var hostedRaveName: String = ""
    var hostedRaveDate: Date = .now
    var hostedRaveVenue: String = ""
    var hostedRaveDetails: String = ""
    var personality: String     // one of RaverPersonality, e.g. "Night Owl"
    var genres: [String]        // music taste — ["Techno", "Melodic Techno", ...]
    var venues: [String]        // preferred vibes — ["Club", "Indoor", "Home", ...]
    var favoriteArtists: [String]
    var partiesCount: Int
    var piecesOwned: Int
    var crewCount: Int
}
