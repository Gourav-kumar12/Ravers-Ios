import Foundation
import Testing
@testable import Ravers_ios

@MainActor
struct MatchPersistenceTests {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "match-persistence-\(UUID())")! }

    @Test func freshLoginRestoresMatchAndOriginalUnlockWithoutLocalCache() async throws {
        let service = HistorySocialStub()
        var date = Date(timeIntervalSince1970: 1000)
        let account = UUID()
        let first = MatchStore(userID: account, service: service, now: { date }, defaults: defaults())
        await first.load()
        let sample = try #require(first.topCandidate)
        await first.like(sample)
        let unlock = try #require(first.chatUnlockDate(for: sample))
        date.addTimeInterval(3600)
        let reopened = MatchStore(userID: account, service: service, now: { date }, defaults: defaults())
        await reopened.load()
        #expect(reopened.matches == [sample])
        #expect(reopened.chatUnlockDate(for: sample) == unlock)
        #expect(!reopened.candidates.contains(sample))
        #expect(reopened.lastMatch == nil)
        #expect(!reopened.canChat(with: sample))
        date = unlock
        #expect(reopened.canChat(with: sample))
        #expect(await reopened.send("Hello again", to: sample))
        let third = MatchStore(userID: account, service: service, now: { date }, defaults: defaults())
        await third.load()
        #expect(third.thread(for: sample).map(\.text) == ["Hello again"])
        #expect(third.chatUnlockDate(for: sample) == unlock)
    }

    @Test func failedSaveDoesNotCreateMatchOrRemoveCandidate() async throws {
        let service = HistorySocialStub()
        let store = MatchStore(userID: UUID(), service: service, defaults: defaults())
        await store.load()
        let sample = try #require(store.topCandidate)
        service.failWrites = true
        await store.like(sample)
        #expect(store.matches.isEmpty)
        #expect(store.lastMatch == nil)
        #expect(store.candidates.contains(sample))
        #expect(store.errorMessage != nil)
    }

    @Test func failedRestoreCannotStartAnotherSampleTimer() async {
        let service = HistorySocialStub()
        service.failHistory = true
        let store = MatchStore(userID: UUID(), service: service, defaults: defaults())
        await store.load()
        store.loadIfNeeded()
        #expect(store.candidates.isEmpty)
        #expect(store.errorMessage != nil)
        #expect(service.saved == nil)
    }

    @Test func unmatchAndPassRemainSavedOnFreshLogin() async throws {
        let service = HistorySocialStub()
        let account = UUID()
        let store = MatchStore(userID: account, service: service, defaults: defaults())
        await store.load()
        let liked = try #require(store.topCandidate)
        await store.like(liked)
        let passed = try #require(store.topCandidate)
        await store.pass(passed)
        #expect(await store.unmatch(liked))
        let reopened = MatchStore(userID: account, service: service, defaults: defaults())
        await reopened.load()
        #expect(reopened.matches.isEmpty)
        #expect(!reopened.candidates.contains(liked))
        #expect(!reopened.candidates.contains(passed))
        // A different signed-in account has a different server-owned history.
        let other = MatchStore(userID: UUID(), service: HistorySocialStub(), defaults: defaults())
        await other.load()
        #expect(other.matches.isEmpty)
        #expect(other.candidates.contains(liked))
    }

    @Test func staleDeviceCannotOverwriteAnotherDevicesConnection() async throws {
        let service = HistorySocialStub()
        let account = UUID()
        let first = MatchStore(userID: account, service: service, defaults: defaults())
        let second = MatchStore(userID: account, service: service, defaults: defaults())
        await first.load()
        await second.load()
        let sample = try #require(first.topCandidate)
        await first.like(sample)
        let another = try #require(second.candidates.last)
        await second.like(another)
        #expect(second.matches.isEmpty)
        #expect(second.errorMessage != nil)
        await second.load()
        #expect(second.matches == [sample])
        await second.like(another)
        #expect(Set(second.matches.map(\.id)) == Set([sample.id, another.id]))
    }

    @Test func existingLocalHistoryImportsWithItsOriginalDates() async throws {
        let service = HistorySocialStub()
        let account = UUID()
        let cache = defaults()
        let date = Date(timeIntervalSince1970: 1000)
        let sample = MatchStore.sampleRavers[0]
        let match = PartnerMatch(id: "demo-\(sample.id)", matchedAt: date,
            chatUnlocksAt: date.addingTimeInterval(10800), raver: sample)
        let history = SampleSocialHistory(matches: [match], messages: [:], dismissedIDs: [sample.id])
        cache.set(try JSONEncoder().encode(history), forKey: "raverse.demo-social.\(account.uuidString.lowercased())")
        let store = MatchStore(userID: account, service: service, defaults: cache)
        await store.load()
        #expect(service.saved?.history.matches == [match])
        #expect(store.chatUnlockDate(for: sample) == match.chatUnlocksAt)
        #expect(!store.candidates.contains(sample))
    }

    @Test func discoveryFailureDoesNotPreventRestoringRealMatches() async {
        let service = HistorySocialStub()
        let real = RaverProfile(id: UUID().uuidString, name: "Raver", age: 0, distanceKm: 0,
            imageName: "", genres: [], artists: [], anthem: "", bio: "")
        let pair = PartnerMatch(id: UUID().uuidString, matchedAt: .distantPast,
            chatUnlocksAt: .distantPast, raver: real)
        service.realMatches = [pair]
        service.failDiscovery = true
        let store = MatchStore(userID: UUID(), service: service, defaults: defaults())
        await store.load()
        #expect(store.match(for: real) == pair)
        #expect(store.canChat(with: real))
        #expect(store.errorMessage != nil)
    }
}

@MainActor
private final class HistorySocialStub: SocialServicing {
    var saved: SampleSocialSnapshot?
    var failWrites = false
    var failHistory = false
    var failDiscovery = false
    var realMatches: [PartnerMatch] = []
    func sampleHistory() async throws -> SampleSocialSnapshot? {
        if failHistory { throw SocialError.unavailable }
        return saved
    }
    func saveSampleHistory(_ history: SampleSocialHistory, revision: Int) async throws -> SampleSocialSnapshot {
        guard !failWrites, revision == (saved?.revision ?? 0) else { throw SocialError.unavailable }
        let snapshot = SampleSocialSnapshot(history: history, revision: revision + 1)
        saved = snapshot
        return snapshot
    }
    func candidates() async throws -> [RaverProfile] {
        if failDiscovery { throw SocialError.unavailable }
        return []
    }
    func matches() async throws -> [PartnerMatch] { realMatches }
    func swipe(_ raverID: String, action: String) async throws { throw SocialError.unavailable }
    func unmatch(_ matchID: String) async throws { throw SocialError.unavailable }
    func messages(_ match: PartnerMatch) async throws -> [ChatMessage] { [] }
    func send(_ text: String, id: UUID, match: PartnerMatch) async throws -> ChatMessage { throw SocialError.unavailable }
    func eventRoom(_ eventID: String) async throws -> EventChatRoom { throw SocialError.unavailable }
    func eventMessages(_ eventID: String) async throws -> [EventChatMessage] { [] }
    func sendEvent(_ text: String, id: UUID, eventID: String) async throws { throw SocialError.unavailable }
}
