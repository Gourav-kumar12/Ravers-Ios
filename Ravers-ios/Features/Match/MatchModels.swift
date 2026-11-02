import Foundation

/// A private, account-owned snapshot of simulated connections. Real people use
/// the server-controlled partner_matches and partner_messages tables.
struct SampleSocialHistory: Codable {
    var matches: [PartnerMatch] = []
    var messages: [String: [ChatMessage]] = [:]
    var dismissedIDs: Set<String> = []
}

struct SampleSocialSnapshot: Decodable {
    let history: SampleSocialHistory
    let revision: Int
}

struct RaverProfile: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var age: Int
    var distanceKm: Double
    var imageName: String
    var genres: [String]
    var artists: [String]
    var anthem: String
    var bio: String
    var city: String? = nil
    var isDemo: Bool { UUID(uuidString: id) == nil }
}

struct PartnerMatch: Identifiable, Codable, Hashable {
    let id: String
    let matchedAt: Date
    let chatUnlocksAt: Date
    var raver: RaverProfile
    enum CodingKeys: String, CodingKey {
        case id, raver
        case matchedAt = "matched_at", chatUnlocksAt = "chat_unlocks_at"
    }
}

struct EventChatRoom: Decodable, Equatable {
    let eventID: String
    let eventName: String
    let memberCount: Int
    enum CodingKeys: String, CodingKey {
        case eventID = "event_id", eventName = "event_name", memberCount = "member_count"
    }
}

struct EventChatMessage: Identifiable, Equatable {
    let id: String
    let senderName: String
    let text: String
    let isMine: Bool
    let sentAt: Date
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: String
    let raverID: String
    var text: String
    var isMine: Bool
    var sentAt: Date
    init(id: String = UUID().uuidString, raverID: String, text: String, isMine: Bool, sentAt: Date = .now) {
        self.id = id
        self.raverID = raverID
        self.text = text
        self.isMine = isMine
        self.sentAt = sentAt
    }
}
