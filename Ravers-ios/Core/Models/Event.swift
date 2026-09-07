//
//  Event.swift
//  Raverse-ios
//
//  A party/event in the Party feed and its detail screen.
//

import Foundation

struct Event: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var venue: String
    var city: String
    var distanceKm: Double?
    var date: Date
    var genres: [String]        // e.g. ["Techno", "Industrial"]
    var fromPrice: Int
    var imageName: String
    var passes: [Pass]

    // MARK: - Detail-screen extras (all optional; feed-only events can omit them)

    /// Doors / close labels, e.g. "21:00" and "04:00".
    var startTimeText: String? = nil
    var endTimeText: String? = nil
    /// Set list in running order.
    var lineup: [LineupSlot] = []
    /// "THE ROOM" blurb.
    var about: String? = nil
    /// Section title above `about` (defaults to THE ROOM).
    var aboutTitle: String = "THE ROOM"
    /// How many people are going.
    var goingCount: Int? = nil
    /// A pass the current user already holds for this event.
    var heldPass: HeldPass? = nil
    /// Preview of the event's group chat.
    var chatPreview: ChatPreview? = nil
}

/// One artist slot in the lineup.
struct LineupSlot: Identifiable, Codable, Hashable {
    var id: String { "\(time)-\(artist)" }
    var time: String            // "21:00"
    var artist: String          // "NULLPOINT"
    var isHeadline: Bool = false
}

/// A pass the user is holding for an event (drives the "PASS ACTIVE" card).
struct HeldPass: Codable, Hashable {
    var tierName: String        // "Phase 1"
    var entries: Int            // 1
    var code: String            // "RV70CS02XR5H2V"
}

/// Preview of an event's group chat.
struct ChatPreview: Codable, Hashable {
    var isOpen: Bool
    var lastSender: String      // "Aarav"
    var lastMessage: String     // "Earplugs at the bar are free this time…"
}
