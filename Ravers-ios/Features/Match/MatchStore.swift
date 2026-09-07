//
//  MatchStore.swift
//  Raverse-ios
//


import SwiftUI

@Observable
final class MatchStore {
    /// Ravers still to be swiped, front of the array = top card.
    var candidates: [RaverProfile] = []
    /// Ravers the user has liked and matched with.
    var matches: [RaverProfile] = []
    /// Chat threads keyed by the other raver's id.
    var messages: [String: [ChatMessage]] = [:]

    /// The raver just matched, used to flash the match banner. Cleared on dismiss.
    var lastMatch: RaverProfile?

    var hasCandidates: Bool { !candidates.isEmpty }
    var topCandidate: RaverProfile? { candidates.first }

    // MARK: - Swiping

    /// Skip the top card — not interested.
    func pass(_ raver: RaverProfile) {
        candidates.removeAll { $0.id == raver.id }
    }

    /// Like the top card. For now every like is mutual (a real backend would
    /// only match when the other raver has also liked back).
    func like(_ raver: RaverProfile) {
        candidates.removeAll { $0.id == raver.id }
        guard !matches.contains(where: { $0.id == raver.id }) else { return }
        matches.insert(raver, at: 0)
        // Seed the thread with an opener so the chat isn't empty.
        messages[raver.id] = [
            ChatMessage(raverID: raver.id,
                        text: "You matched with \(raver.name.components(separatedBy: " ").first ?? raver.name). Say hi 👋",
                        isMine: false)
        ]
        lastMatch = raver
    }

    // MARK: - Matches

    func isMatched(_ raver: RaverProfile) -> Bool {
        matches.contains { $0.id == raver.id }
    }

    /// Drop a match and wipe its chat thread.
    func unmatch(_ raver: RaverProfile) {
        matches.removeAll { $0.id == raver.id }
        messages[raver.id] = nil
        if lastMatch?.id == raver.id { lastMatch = nil }
    }

    // MARK: - Chat

    func thread(for raver: RaverProfile) -> [ChatMessage] {
        messages[raver.id] ?? []
    }

    func send(_ text: String, to raver: RaverProfile) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages[raver.id, default: []].append(
            ChatMessage(raverID: raver.id, text: trimmed, isMine: true)
        )
    }

    // MARK: - Sample data

    /// Seeds the discovery deck once. Replace with a Supabase query later.
    func loadIfNeeded() {
        guard candidates.isEmpty && matches.isEmpty else { return }
        candidates = MatchStore.sampleRavers
    }

    static let sampleRavers: [RaverProfile] = [
        RaverProfile(
            id: "zoya", name: "Zoya", age: 26, distanceKm: 3.1,
            imageName: "raver-zoya",
            genres: ["Drum & Bass", "Techno"],
            artists: ["Sub Focus", "Nolsie"],
            anthem: "Hooked to Bassment 004",
            bio: "I fly to Mumbai for 170 BPM and stand exactly one row off the rail. If the ceiling is low and the sub is loud, I'm home."
        ),
        RaverProfile(
            id: "arjun", name: "Arjun", age: 29, distanceKm: 5.4,
            imageName: "raver-arjun",
            genres: ["Melodic Techno", "Progressive"],
            artists: ["Tale Of Us", "Colyn"],
            anthem: "Front-left at Void Frequency",
            bio: "Sunrise sets over drops. I'll trade you a warehouse coordinate for a good coffee the morning after."
        ),
        RaverProfile(
            id: "meher", name: "Meher", age: 24, distanceKm: 1.8,
            imageName: "raver-meher",
            genres: ["House", "Deep House"],
            artists: ["Peggy Gou", "ARKA"],
            anthem: "Rooftop regular",
            bio: "Groove over speed. Find me by the booth asking the DJ what that edit was."
        )
    ]
}
