import SwiftUI

@MainActor
@Observable
final class EventChatStore {
    private(set) var room: EventChatRoom?
    private(set) var messages: [EventChatMessage] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var errorMessage: String?
    private let eventID: String
    private let service: any SocialServicing

    init(eventID: String, service: (any SocialServicing)? = nil) {
        self.eventID = eventID
        self.service = service ?? SocialService()
    }
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let joined = try await service.eventRoom(eventID)
            let thread = try await service.eventMessages(eventID)
            guard !Task.isCancelled else { return }
            room = joined
            messages = thread
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            // A refund or cancellation removes membership; do not keep showing stale chat.
            room = nil
            messages = []
            errorMessage = "Couldn't open this group. A paid ticket for this event is required. If you already have one, retry when connected."
        }
    }
    func send(_ text: String, id: UUID) async -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard room != nil, !isSending, !clean.isEmpty, clean.count <= 2000 else { return false }
        isSending = true
        defer { isSending = false }
        do {
            try await service.sendEvent(clean, id: id, eventID: eventID)
            await load()
            return true
        } catch {
            errorMessage = "Couldn't send your message. Retry, or refresh to check your ticket access."
            return false
        }
    }
}
