//
//  MatchModels.swift
//  Raverse-ios


import Foundation

/// Another raver as seen in discovery — the public card shown in NEARBY RAVERS.
struct RaverProfile: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var age: Int
    var distanceKm: Double
    var imageName: String        // asset name or remote URL (gradient fallback if missing)
    var genres: [String]
    var artists: [String]
    var anthem: String           // e.g. "Hooked to Bassment 004"
    var bio: String
}

/// One message in a match's chat thread.
struct ChatMessage: Identifiable, Codable, Hashable {
    let id: String
    let raverID: String          // the other raver this thread belongs to
    var text: String
    var isMine: Bool             // true = sent by the signed-in user
    var sentAt: Date

    init(id: String = UUID().uuidString, raverID: String, text: String, isMine: Bool, sentAt: Date = .now) {
        self.id = id
        self.raverID = raverID
        self.text = text
        self.isMine = isMine
        self.sentAt = sentAt
    }
}
