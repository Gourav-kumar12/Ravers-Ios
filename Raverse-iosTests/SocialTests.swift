import Foundation
import Testing
@testable import Ravers_ios

@MainActor
struct SocialTests {
    @Test func sampleDeckIsAvailableAndPassNeverContactsServer() async {
        let service = SocialStub()
        let store = MatchStore(service: service)
        let sample = store.candidates[0]
        #expect(sample.isDemo)
        await store.pass(sample)
        #expect(!store.candidates.contains(sample))
        #expect(store.matches.isEmpty)
        #expect(service.swipes.isEmpty)
        await store.load()
        #expect(!store.candidates.contains(sample))
    }

    @Test func sampleMatchWaitsThreeHoursAndPersistsForOnlyItsAccount() async throws {
        let service = SocialStub()
        let suite = "social-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var date = Date(timeIntervalSince1970: 1000)
        let userID = UUID()
        let store = MatchStore(userID: userID, service: service, now: { date }, defaults: defaults)
        await store.load()
        let sample = store.candidates[0]
        await store.like(sample)
        #expect(store.matches == [sample])
        #expect(store.chatUnlockDate(for: sample) == date.addingTimeInterval(10800))
        #expect(await store.send("Too soon", to: sample) == false)
        #expect(store.thread(for: sample).isEmpty)
        date.addTimeInterval(10799)
        #expect(!store.canChat(with: sample))
        date.addTimeInterval(1)
        #expect(await store.send("Hello", to: sample))
        let reopened = MatchStore(userID: userID, service: service, now: { date }, defaults: defaults)
        await reopened.load()
        #expect(reopened.matches == [sample])
        #expect(reopened.thread(for: sample).map(\.text) == ["Hello"])
        let other = MatchStore(userID: UUID(), service: service, defaults: defaults)
        #expect(other.matches.isEmpty)
        #expect(service.swipes.isEmpty)
        #expect(service.sentDirect == 0)
    }

    @Test func realLikeWaitsForServerMutualMatchAndUsesServerUnlockTime() async {
        let service = SocialStub()
        let real = person()
        service.people = [real]
        let store = MatchStore(service: service, now: { Date(timeIntervalSince1970: 1000) })
        await store.load()
        await store.like(real)
        #expect(service.swipes == ["like"])
        #expect(store.matches.isEmpty)
        #expect(!store.canChat(with: real))
        let date = Date(timeIntervalSince1970: 2000)
        service.pairs = [PartnerMatch(id: UUID().uuidString, matchedAt: date,
                                     chatUnlocksAt: date.addingTimeInterval(10800), raver: real)]
        await store.load()
        #expect(store.matches == [real])
        #expect(store.lastMatch == real)
        #expect(!store.canChat(with: real))
        #expect(await store.send("Too soon", to: real) == false)
        #expect(service.sentDirect == 0)
    }

    @Test func failedSwipeKeepsCandidateAndDoesNotInventMatch() async {
        let service = SocialStub()
        let real = person()
        service.people = [real]
        let store = MatchStore(service: service)
        await store.load()
        service.failWrites = true
        await store.like(real)
        #expect(store.candidates == [real])
        #expect(store.matches.isEmpty)
        #expect(store.errorMessage != nil)
    }

    @Test func failedMessageOrUnmatchKeepsExistingConnection() async {
        let service = SocialStub()
        let real = person()
        service.pairs = [PartnerMatch(id: UUID().uuidString, matchedAt: .distantPast,
                                     chatUnlocksAt: .distantPast, raver: real)]
        let store = MatchStore(service: service)
        await store.load()
        service.failWrites = true
        #expect(await store.send("Keep my draft", to: real) == false)
        #expect(store.thread(for: real).isEmpty)
        #expect(await store.unmatch(real) == false)
        #expect(store.matches == [real])
        service.failWrites = false
        let requestID = UUID()
        #expect(await store.send("Hello", to: real, id: requestID))
        #expect(await store.send("Hello", to: real, id: requestID))
        #expect(store.thread(for: real).count == 1)
        service.pairs = []
        await store.load()
        #expect(store.matches.isEmpty)
        #expect(store.thread(for: real).isEmpty)
        #expect(!store.canChat(with: real))
    }

    @Test func eventChatRequiresServerMembershipAndClearsRevokedHistory() async {
        let service = SocialStub()
        let store = EventChatStore(eventID: "event-one", service: service)
        await store.load()
        #expect(store.room == nil)
        #expect(await store.send("Forbidden", id: UUID()) == false)
        service.allowedEvent = "event-one"
        await store.load()
        #expect(store.room?.eventID == "event-one")
        #expect(await store.send("See you there", id: UUID()))
        #expect(store.messages.map(\.text) == ["See you there"])
        let otherEvent = EventChatStore(eventID: "event-two", service: service)
        await otherEvent.load()
        #expect(otherEvent.room == nil)
        service.allowedEvent = nil
        await store.load()
        #expect(store.room == nil)
        #expect(store.messages.isEmpty)
        #expect(await store.send("After refund", id: UUID()) == false)
    }

    private func person() -> RaverProfile {
        RaverProfile(id: UUID().uuidString, name: "Real Raver", age: 0, distanceKm: 0,
                     imageName: "", genres: ["Techno"], artists: [], anthem: "Night Owl", bio: "")
    }
}

@MainActor
private final class SocialStub: SocialServicing {
    var sampleSnapshot: SampleSocialSnapshot?
    func sampleHistory() async throws -> SampleSocialSnapshot? { sampleSnapshot }
    func saveSampleHistory(_ history: SampleSocialHistory, revision: Int) async throws -> SampleSocialSnapshot {
        guard !failWrites, revision == (sampleSnapshot?.revision ?? 0) else { throw SocialError.unavailable }
        let saved = SampleSocialSnapshot(history: history, revision: revision + 1)
        sampleSnapshot = saved
        return saved
    }
    var people: [RaverProfile] = []
    var pairs: [PartnerMatch] = []
    var swipes: [String] = []
    var sentDirect = 0
    var failWrites = false
    var allowedEvent: String?
    var groupMessages: [EventChatMessage] = []
    func candidates() async throws -> [RaverProfile] { people }
    func matches() async throws -> [PartnerMatch] { pairs }
    func swipe(_ raverID: String, action: String) async throws {
        if failWrites { throw SocialError.unavailable }
        swipes.append(action)
        people.removeAll { $0.id == raverID }
    }
    func unmatch(_ matchID: String) async throws {
        if failWrites { throw SocialError.unavailable }
        pairs.removeAll { $0.id == matchID }
    }
    func messages(_ match: PartnerMatch) async throws -> [ChatMessage] { [] }
    func send(_ text: String, id: UUID, match: PartnerMatch) async throws -> ChatMessage {
        if failWrites { throw SocialError.unavailable }
        sentDirect += 1
        return ChatMessage(id: id.uuidString, raverID: match.raver.id, text: text, isMine: true)
    }
    func eventRoom(_ eventID: String) async throws -> EventChatRoom {
        guard allowedEvent == eventID else { throw SocialError.unavailable }
        return EventChatRoom(eventID: eventID, eventName: "Test event", memberCount: 2)
    }
    func eventMessages(_ eventID: String) async throws -> [EventChatMessage] {
        guard allowedEvent == eventID else { throw SocialError.unavailable }
        return groupMessages
    }
    func sendEvent(_ text: String, id: UUID, eventID: String) async throws {
        guard allowedEvent == eventID else { throw SocialError.unavailable }
        groupMessages.append(EventChatMessage(id: id.uuidString, senderName: "You", text: text, isMine: true, sentAt: .now))
    }
}
