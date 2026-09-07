//
//  UserProfile.swift
//  Raverse-ios
//
//  The signed-in user's profile (Profile tab).
//

import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String     // "REHAN MALHOTRA"
    var handle: String          // "@rehan.wav"
    var email: String           // "rehan@raverse.app"
    var phone: String           // "+91 98765 43210"
    var city: String
    var memberSince: String     // "March 2025"
    var avatarName: String
    var personality: String     // one of RaverPersonality, e.g. "Night Owl"
    var genres: [String]        // music taste — ["Techno", "Melodic Techno", ...]
    var venues: [String]        // preferred vibes — ["Club", "Indoor", "Home", ...]
    var favoriteArtists: [String]
    var partiesCount: Int
    var piecesOwned: Int
    var crewCount: Int
}
