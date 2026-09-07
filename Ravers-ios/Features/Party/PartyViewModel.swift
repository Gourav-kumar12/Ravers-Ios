//
//  PartyViewModel.swift
//  Raverse-ios
//

import SwiftUI

@Observable
final class PartyViewModel {
    var events: [Event] = []
    var genres: [String] = ["All", "Techno", "Melodic Techno", "House",
                            "Drum & Bass", "Minimal", "Psytrance"]
    var selectedGenre = "All"
    var locationLabel = "Near HSR Layout, Bengaluru"

    /// Events matching the selected genre chip.
    var filteredEvents: [Event] {
        guard selectedGenre != "All" else { return events }
        return events.filter { $0.genres.contains(selectedGenre) }
    }

    func load() async {
        guard events.isEmpty else { return }
        events = PartyViewModel.sampleEvents
    }

    // MARK: - Sample data (until Supabase is wired)

    private static var sampleEvents: [Event] {
        let cal = Calendar.current
        func date(_ day: Int) -> Date {
            var c = DateComponents()
            c.year = 2026; c.month = 8; c.day = day; c.hour = 22
            return cal.date(from: c) ?? .now
        }
        return [
            Event(
                id: "evt-void-frequency",
                name: "VOID FREQUENCY",
                venue: "Warehouse 7, Peenya Industrial Area",
                city: "Bengaluru",
                distanceKm: 14.2,
                date: date(8),
                genres: ["Techno", "Industrial"],
                fromPrice: 799,
                imageName: "party-1",
                passes: [
                    Pass(id: "p1", name: "Phase 1", detail: "Entry", price: 799, remaining: 42),
                    Pass(id: "p2", name: "Phase 2", detail: "Entry", price: 999, remaining: 120)
                ],
                startTimeText: "21:00",
                endTimeText: "04:00",
                lineup: [
                    LineupSlot(time: "21:00", artist: "NULLPOINT"),
                    LineupSlot(time: "23:00", artist: "Tremor Kaur"),
                    LineupSlot(time: "01:00", artist: "ARKA"),
                    LineupSlot(time: "03:00", artist: "ARKA b2b NULLPOINT", isHeadline: true)
                ],
                about: "Raw industrial techno inside a working warehouse. One room, one system, zero phones on the floor. Strict door, pass and ID only.",
                goingCount: 412,
                heldPass: HeldPass(tierName: "Phase 1", entries: 1, code: "RV70CS02XR5H2V"),
                chatPreview: ChatPreview(
                    isOpen: true,
                    lastSender: "Aarav",
                    lastMessage: "Earplugs at the bar are free this time. Take them."
                )
            ),
            Event(
                id: "evt-bassment-004",
                name: "BASSMENT 004",
                venue: "The Bunker, Lower Parel",
                city: "Mumbai",
                distanceKm: nil,
                date: date(9),
                genres: ["Drum & Bass", "Bass"],
                fromPrice: 899,
                imageName: "party-2",
                passes: [
                    Pass(id: "p1", name: "Phase 1", detail: "Entry", price: 899, remaining: 18)
                ],
                startTimeText: "21:00",
                endTimeText: "04:00",
                lineup: [
                    LineupSlot(time: "21:00", artist: "NULLPOINT"),
                    LineupSlot(time: "23:00", artist: "Tremor Kaur"),
                    LineupSlot(time: "01:00", artist: "ARKA"),
                    LineupSlot(time: "03:00", artist: "ARKA b2b NULLPOINT", isHeadline: true)
                ],
                about: "Raw industrial techno inside a working warehouse. One room, one system, zero phones on the floor. Strict door, pass and ID only.",
                goingCount: 412,
                heldPass: HeldPass(tierName: "Phase 1", entries: 1, code: "RV70CS02XR5H2V"),
                chatPreview: ChatPreview(
                    isOpen: true,
                    lastSender: "Aarav",
                    lastMessage: "Earplugs at the bar are free this time. Take them."
                )
            ),
            Event(
                id: "evt-bassment-005",
                name: "BASSMENT 005",
                venue: "The Bunker, Lower Parel",
                city: "Delhi",
                distanceKm: 20.4,
                date: date(9),
                genres: ["House"],
                fromPrice: 899,
                imageName: "party-3",
                passes: [
                    Pass(id: "p1", name: "Phase 1", detail: "Entry", price: 899, remaining: 18)
                ]
            )

        ]
    }
}
