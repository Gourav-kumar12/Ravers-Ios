import Foundation
import Supabase

@MainActor
protocol SocialServicing {
    func candidates() async throws -> [RaverProfile]
    func matches() async throws -> [PartnerMatch]
    func swipe(_ raverID: String, action: String) async throws
    func unmatch(_ matchID: String) async throws
    func messages(_ match: PartnerMatch) async throws -> [ChatMessage]
    func send(_ text: String, id: UUID, match: PartnerMatch) async throws -> ChatMessage
    func eventRoom(_ eventID: String) async throws -> EventChatRoom
    func eventMessages(_ eventID: String) async throws -> [EventChatMessage]
    func sendEvent(_ text: String, id: UUID, eventID: String) async throws
    func sampleHistory() async throws -> SampleSocialSnapshot?
    func saveSampleHistory(_ history: SampleSocialHistory, revision: Int) async throws -> SampleSocialSnapshot
}

extension SocialServicing {
    func sampleHistory() async throws -> SampleSocialSnapshot? { throw SocialError.unavailable }
    func saveSampleHistory(_ history: SampleSocialHistory, revision: Int) async throws -> SampleSocialSnapshot {
        throw SocialError.unavailable
    }
}

enum SocialError: LocalizedError {
    case notAuthenticated, chatLocked, unavailable, invalidMessage
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Sign in again to connect with other ravers."
        case .chatLocked: "Chat opens three hours after you both match."
        case .unavailable: "Live connections are temporarily unavailable. Please try again."
        case .invalidMessage: "Write a message between 1 and 2,000 characters."
        }
    }
}

/// Real matches and chat access are controlled by server functions. Sample
/// history is private account data and never grants access to another person.
@MainActor
final class SocialService: SocialServicing {
    private let expectedUserID: UUID?
    init(userID: UUID? = nil) { expectedUserID = userID }

    private func client() async throws -> (SupabaseClient, UUID) {
        let client = try SupabaseManager.shared.makeClient()
        let session = try await client.auth.session
        guard AuthService.isVerifiedEmailUser(session.user),
              expectedUserID == nil || session.user.id == expectedUserID else {
            throw SocialError.notAuthenticated
        }
        return (client, session.user.id)
    }
    private func checkOwner(_ userID: UUID, _ client: SupabaseClient) throws {
        guard client.auth.currentUser?.id == userID else { throw SocialError.notAuthenticated }
    }
    private func photo(_ raver: RaverProfile, client: SupabaseClient) throws -> RaverProfile {
        var result = raver
        if !raver.imageName.isEmpty {
            result.imageName = try client.storage.from("profile-images").getPublicURL(path: raver.imageName).absoluteString
        }
        return result
    }
    func sampleHistory() async throws -> SampleSocialSnapshot? {
        let (client, userID) = try await client()
        let rows: [SampleSocialSnapshot] = try await client.from("partner_sample_history")
            .select("history,revision").eq("user_id", value: userID.uuidString).limit(1).execute().value
        try checkOwner(userID, client)
        return rows.first
    }
    func saveSampleHistory(_ history: SampleSocialHistory, revision: Int) async throws -> SampleSocialSnapshot {
        let (client, userID) = try await client()
        let saved: SampleSocialSnapshot = try await client.rpc("save_partner_sample_history",
            params: SampleHistoryWrite(p_history: history, p_revision: revision)).single().execute().value
        try checkOwner(userID, client)
        return saved
    }
    func candidates() async throws -> [RaverProfile] {
        let (client, userID) = try await client()
        let rows: [RaverProfile] = try await client.rpc("get_partner_candidates").execute().value
        try checkOwner(userID, client)
        return try rows.map { try photo($0, client: client) }
    }
    func matches() async throws -> [PartnerMatch] {
        let (client, userID) = try await client()
        var rows: [PartnerMatch] = try await client.rpc("get_partner_matches").execute().value
        try checkOwner(userID, client)
        for index in rows.indices { rows[index].raver = try photo(rows[index].raver, client: client) }
        return rows
    }
    func swipe(_ raverID: String, action: String) async throws {
        let (client, userID) = try await client()
        try await client.rpc("record_partner_swipe", params: ["p_target": raverID, "p_action": action]).execute()
        try checkOwner(userID, client)
    }
    func unmatch(_ matchID: String) async throws {
        let (client, userID) = try await client()
        try await client.rpc("end_partner_match", params: ["p_match": matchID]).execute()
        try checkOwner(userID, client)
    }
    func messages(_ match: PartnerMatch) async throws -> [ChatMessage] {
        let (client, userID) = try await client()
        let rows: [MessageRow] = try await client.from("partner_messages").select()
            .eq("match_id", value: match.id).order("created_at", ascending: false).order("id", ascending: false)
            .limit(100).execute().value
        try checkOwner(userID, client)
        return rows.reversed().map { $0.direct(raverID: match.raver.id, userID: userID) }
    }
    func send(_ text: String, id: UUID, match: PartnerMatch) async throws -> ChatMessage {
        let (client, userID) = try await client()
        let row: MessageRow = try await client.rpc("send_partner_message", params: [
            "p_id": id.uuidString, "p_match": match.id, "p_body": text
        ]).single().execute().value
        try checkOwner(userID, client)
        return row.direct(raverID: match.raver.id, userID: userID)
    }
    func eventRoom(_ eventID: String) async throws -> EventChatRoom {
        let (client, userID) = try await client()
        let room: EventChatRoom = try await client.rpc("join_event_chat", params: ["p_event": eventID])
            .single().execute().value
        try checkOwner(userID, client)
        return room
    }
    func eventMessages(_ eventID: String) async throws -> [EventChatMessage] {
        let (client, userID) = try await client()
        let rows: [MessageRow] = try await client.rpc("get_event_chat_messages", params: ["p_event": eventID])
            .execute().value
        try checkOwner(userID, client)
        return rows.reversed().map {
            EventChatMessage(id: $0.id, senderName: $0.senderName ?? "Raver", text: $0.body,
                             isMine: UUID(uuidString: $0.senderID) == userID, sentAt: $0.createdAt)
        }
    }
    func sendEvent(_ text: String, id: UUID, eventID: String) async throws {
        let (client, userID) = try await client()
        let _: MessageRow = try await client.rpc("send_event_chat_message", params: [
            "p_id": id.uuidString, "p_event": eventID, "p_body": text
        ]).single().execute().value
        try checkOwner(userID, client)
    }
}

private struct SampleHistoryWrite: Encodable {
    let p_history: SampleSocialHistory
    let p_revision: Int
}

private struct MessageRow: Decodable {
    let id: String
    let senderID: String
    let senderName: String?
    let body: String
    let createdAt: Date
    enum CodingKeys: String, CodingKey {
        case id, body
        case senderID = "sender_id", senderName = "sender_name", createdAt = "created_at"
    }
    func direct(raverID: String, userID: UUID) -> ChatMessage {
        ChatMessage(id: id, raverID: raverID, text: body,
                    isMine: UUID(uuidString: senderID) == userID, sentAt: createdAt)
    }
}
