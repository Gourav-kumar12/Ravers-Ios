import SwiftUI

@MainActor
@Observable
final class MatchStore {
    private(set) var candidates: [RaverProfile] = []
    private(set) var records: [PartnerMatch] = []
    private(set) var messages: [String: [ChatMessage]] = [:]
    private(set) var isLoading = false
    private(set) var isUpdating = false
    private(set) var isSending = false
    private(set) var errorMessage: String?
    var lastMatch: RaverProfile?
    var notice: String?
    private var dismissedDemoIDs: Set<String> = []
    private var hasLoaded = false
    private let service: any SocialServicing
    private let now: () -> Date
    private let defaults: UserDefaults?
    private let cacheKey: String?
    private let usesCloudHistory: Bool
    private var sampleHistoryLoaded: Bool
    private var sampleRevision = 0

    init(userID: UUID? = nil, service: (any SocialServicing)? = nil,
         now: @escaping () -> Date = { Date() }, defaults: UserDefaults? = nil) {
        self.service = service ?? SocialService(userID: userID)
        self.now = now
        usesCloudHistory = userID != nil
        sampleHistoryLoaded = userID == nil
        self.defaults = userID == nil ? nil : (defaults ?? .standard)
        self.cacheKey = userID.map { "raverse.demo-social.\($0.uuidString.lowercased())" }
        if let cacheKey, let data = self.defaults?.data(forKey: cacheKey),
           let history = try? JSONDecoder().decode(SampleSocialHistory.self, from: data) {
            applySampleHistory(history)
        }
        showSamples()
    }

    var matches: [RaverProfile] { records.map(\.raver) }
    var hasCandidates: Bool { !candidates.isEmpty }
    var topCandidate: RaverProfile? { candidates.first }
    var isBusy: Bool { isLoading || isUpdating }
    var showingSamples: Bool { candidates.first?.isDemo == true }
    var samplesSavedToAccount: Bool { usesCloudHistory }

    func match(for raver: RaverProfile) -> PartnerMatch? { records.first { $0.raver.id == raver.id } }
    func chatUnlockDate(for raver: RaverProfile) -> Date? { match(for: raver)?.chatUnlocksAt }
    func canChat(with raver: RaverProfile, at date: Date? = nil) -> Bool {
        guard !raver.isDemo || sampleHistoryLoaded,
              let unlock = chatUnlockDate(for: raver) else { return false }
        return unlock <= (date ?? now())
    }
    func isMatched(_ raver: RaverProfile) -> Bool { match(for: raver) != nil }

    func load() async {
        guard !isBusy, !isSending else { return }
        isLoading = true
        defer { isLoading = false }
        var failures: [String] = []
        // Restore each source independently. A failed discovery request must not
        // prevent saved matches or the original countdown from being restored.
        if usesCloudHistory {
            do {
                if let saved = try await service.sampleHistory() {
                    guard !Task.isCancelled else { return }
                    sampleRevision = saved.revision
                    applySampleHistory(saved.history)
                } else {
                    let local = sampleHistory()
                    if !local.matches.isEmpty || !local.dismissedIDs.isEmpty || !local.messages.isEmpty {
                        // Upload the old per-account cache once, keeping its dates.
                        let saved = try await service.saveSampleHistory(local, revision: 0)
                        guard !Task.isCancelled else { return }
                        sampleRevision = saved.revision
                        applySampleHistory(saved.history)
                    } else {
                        sampleRevision = 0
                        applySampleHistory(SampleSocialHistory())
                    }
                }
                sampleHistoryLoaded = true
                saveDemoHistory()
            } catch {
                guard !Task.isCancelled else { return }
                sampleHistoryLoaded = false
                candidates.removeAll { $0.isDemo }
                failures.append("Couldn't restore your saved sample connections. Retry before swiping.")
            }
        }
        do {
            let live = try await service.matches()
            guard !Task.isCancelled else { return }
            apply(live)
            hasLoaded = true
        } catch {
            guard !Task.isCancelled else { return }
            failures.append("Couldn't refresh your matches. Please retry.")
        }
        do {
            let people = try await service.candidates()
            guard !Task.isCancelled else { return }
            candidates = people.filter { !isMatched($0) }
            if candidates.isEmpty { showSamples() }
        } catch {
            guard !Task.isCancelled else { return }
            failures.append("Live discovery couldn't load. Please retry.")
            if candidates.isEmpty { showSamples() }
        }
        errorMessage = failures.isEmpty ? nil : failures.joined(separator: " ")
    }

    private func apply(_ live: [PartnerMatch]) {
        if hasLoaded, let newMatch = live.first(where: { pair in !records.contains { $0.id == pair.id } }) {
            lastMatch = newMatch.raver
        }
        records = live + records.filter { $0.raver.isDemo }
        let validIDs = Set(records.map { $0.raver.id })
        messages = messages.filter { validIDs.contains($0.key) }
    }
    func pass(_ raver: RaverProfile) async { await swipe(raver, liked: false) }
    func like(_ raver: RaverProfile) async { await swipe(raver, liked: true) }

    private func swipe(_ raver: RaverProfile, liked: Bool) async {
        guard !isBusy, !isSending, candidates.contains(where: { $0.id == raver.id }) else { return }
        isUpdating = true
        defer { isUpdating = false }
        errorMessage = nil
        if raver.isDemo {
            guard sampleHistoryLoaded else { return }
            var history = sampleHistory()
            history.dismissedIDs.insert(raver.id)
            if liked, !isMatched(raver) {
                let date = now()
                history.matches.insert(PartnerMatch(id: "demo-\(raver.id)", matchedAt: date,
                    chatUnlocksAt: date.addingTimeInterval(3 * 3600), raver: raver), at: 0)
            }
            do {
                try await persistSampleHistory(history)
                candidates.removeAll { $0.id == raver.id }
                if liked { lastMatch = raver }
            } catch { errorMessage = "Couldn't save your connection. Refresh and try again." }
            return
        }
        do {
            try await service.swipe(raver.id, action: liked ? "like" : "pass")
            candidates.removeAll { $0.id == raver.id }
            notice = liked ? "Like sent. You'll match when they like you back." : nil
            do {
                let live = try await service.matches()
                let previousIDs = Set(records.map(\.id))
                apply(live)
                if let pair = live.first(where: { !previousIDs.contains($0.id) }) {
                    lastMatch = pair.raver
                    notice = nil
                }
            } catch { errorMessage = "Your swipe was saved. Refresh to check for new matches." }
        } catch { errorMessage = "Couldn't save your swipe. Please try again." }
    }

    func unmatch(_ raver: RaverProfile) async -> Bool {
        guard !isBusy, !isSending, let pair = match(for: raver) else { return false }
        isUpdating = true
        defer { isUpdating = false }
        do {
            if raver.isDemo {
                guard sampleHistoryLoaded else { return false }
                var history = sampleHistory()
                history.matches.removeAll { $0.raver.id == raver.id }
                history.messages[raver.id] = nil
                try await persistSampleHistory(history)
            } else {
                try await service.unmatch(pair.id)
                records.removeAll { $0.raver.id == raver.id }
                messages[raver.id] = nil
            }
            if lastMatch?.id == raver.id { lastMatch = nil }
            return true
        } catch {
            errorMessage = "Couldn't remove this match. Please try again."
            return false
        }
    }
    func thread(for raver: RaverProfile) -> [ChatMessage] { messages[raver.id] ?? [] }
    func loadMessages(for raver: RaverProfile) async {
        guard let pair = match(for: raver), !raver.isDemo, !isSending else { return }
        let knownIDs = Set(thread(for: raver).map(\.id))
        do {
            let thread = try await service.messages(pair)
            guard !Task.isCancelled, isMatched(raver) else { return }
            let receivedIDs = Set(thread.map(\.id))
            let justSent = self.thread(for: raver).filter {
                $0.isMine && !knownIDs.contains($0.id) && !receivedIDs.contains($0.id)
            }
            messages[raver.id] = (thread + justSent).sorted { $0.sentAt < $1.sentAt }
            errorMessage = nil
        } catch { errorMessage = "Couldn't refresh messages. Please try again." }
    }
    @discardableResult
    func send(_ text: String, to raver: RaverProfile, id: UUID = UUID()) async -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 2000, !isSending, !isBusy,
              canChat(with: raver), let pair = match(for: raver) else { return false }
        isSending = true
        defer { isSending = false }
        do {
            if raver.isDemo {
                var history = sampleHistory()
                if history.messages[raver.id, default: []].contains(where: { $0.id == id.uuidString }) { return true }
                history.messages[raver.id, default: []].append(ChatMessage(id: id.uuidString,
                    raverID: raver.id, text: clean, isMine: true, sentAt: now()))
                try await persistSampleHistory(history)
            } else {
                let message = try await service.send(clean, id: id, match: pair)
                guard match(for: raver)?.id == pair.id else { return false }
                if !thread(for: raver).contains(where: { $0.id == message.id }) {
                    messages[raver.id, default: []].append(message)
                }
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Couldn't send your message. Keep it here and try again."
            return false
        }
    }

    func loadIfNeeded() { if candidates.isEmpty { showSamples() } }
    private func showSamples() {
        guard sampleHistoryLoaded else { return }
        candidates = Self.sampleRavers.filter { !dismissedDemoIDs.contains($0.id) && !isMatched($0) }
    }
    func resetSamplePasses() {
        Task {
            guard !isBusy, !isSending, sampleHistoryLoaded else { return }
            isUpdating = true
            defer { isUpdating = false }
            var history = sampleHistory()
            history.dismissedIDs = Set(history.matches.map { $0.raver.id })
            do {
                try await persistSampleHistory(history)
                showSamples()
                errorMessage = nil
            } catch { errorMessage = "Couldn't reset sample passes. Refresh and try again." }
        }
    }
    private func sampleHistory() -> SampleSocialHistory {
        SampleSocialHistory(matches: records.filter { $0.raver.isDemo },
            messages: messages.filter { UUID(uuidString: $0.key) == nil }, dismissedIDs: dismissedDemoIDs)
    }
    private func applySampleHistory(_ history: SampleSocialHistory) {
        let allowed = Set(Self.sampleRavers.map(\.id))
        let samples = history.matches.filter { allowed.contains($0.raver.id) }
        records = records.filter { !$0.raver.isDemo } + samples
        messages = messages.filter { UUID(uuidString: $0.key) != nil }
        let matchedIDs = Set(samples.map { $0.raver.id })
        for (id, thread) in history.messages where matchedIDs.contains(id) { messages[id] = thread }
        dismissedDemoIDs = history.dismissedIDs.intersection(allowed).union(matchedIDs)
    }
    private func persistSampleHistory(_ history: SampleSocialHistory) async throws {
        if usesCloudHistory {
            guard sampleHistoryLoaded else { throw SocialError.unavailable }
            let saved = try await service.saveSampleHistory(history, revision: sampleRevision)
            guard !Task.isCancelled else { throw CancellationError() }
            sampleRevision = saved.revision
            applySampleHistory(saved.history)
        } else {
            applySampleHistory(history)
        }
        saveDemoHistory()
    }
    private func saveDemoHistory() {
        guard let cacheKey, let data = try? JSONEncoder().encode(sampleHistory()) else { return }
        defaults?.set(data, forKey: cacheKey)
    }

    static let sampleRavers: [RaverProfile] = [
        RaverProfile(id: "zoya", name: "Zoya", age: 26, distanceKm: 3.1, imageName: "raver-zoya",
            genres: ["Drum & Bass", "Techno"], artists: ["Sub Focus", "Nolsie"],
            anthem: "Hooked to Bassment 004",
            bio: "I fly to Mumbai for 170 BPM and stand exactly one row off the rail. If the ceiling is low and the sub is loud, I'm home."),
        RaverProfile(id: "arjun", name: "Arjun", age: 29, distanceKm: 5.4, imageName: "raver-arjun",
            genres: ["Melodic Techno", "Progressive"], artists: ["Tale Of Us", "Colyn"],
            anthem: "Front-left at Void Frequency",
            bio: "Sunrise sets over drops. I'll trade you a warehouse coordinate for a good coffee the morning after."),
        RaverProfile(id: "meher", name: "Meher", age: 24, distanceKm: 1.8, imageName: "raver-meher",
            genres: ["House", "Deep House"], artists: ["Peggy Gou", "ARKA"], anthem: "Rooftop regular",
            bio: "Groove over speed. Find me by the booth asking the DJ what that edit was.")
    ]
}
