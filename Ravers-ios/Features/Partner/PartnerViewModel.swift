

import SwiftUI

@Observable
final class PartnerViewModel {
    /// Partner features unlock once the user owns any Partner Key product.
    var isUnlocked = false
    var nearbyCount = 0

    // MARK: - Two required photos (stored as JPEG data)
    var photo1: Data?
    var photo2: Data?

    // MARK: - Taste selections (multi-select chips)
    var genres: Set<String> = []
    var artists: Set<String> = []
    var partyStyles: Set<String> = []

    // MARK: - Chip options (as seen in the design reference)
    let genreOptions = [
        "Techno", "Melodic Techno", "Psytrance", "House", "Deep House",
        "Bollywood", "Bollytech", "Drum & Bass", "Trance", "Minimal",
        "Industrial", "Progressive"
    ]
    let artistOptions = [
        "Amelie Lens", "Tale Of Us", "ARKA", "Colyn", "Astrix", "Vini Vici",
        "Peggy Gou", "Ritviz", "Nucleya", "Sub Focus", "Nolsie", "NULLPOINT",
        "Mirage Skin", "Ana Verma", "BPRDJ", "Ricardo Villalobos"
    ]
    let partyStyleOptions = [
        "Warehouse", "Open-Air", "Rooftop", "Forest", "Bunker", "Afterhours"
    ]

    // MARK: - Progress ("X OF 4 TUNED")

    /// The four things a raver tunes before discovery opens.
    var tunedCount: Int {
        var n = 0
        if photo1 != nil { n += 1 }
        if photo2 != nil { n += 1 }
        if !genres.isEmpty { n += 1 }
        if !artists.isEmpty { n += 1 }
        return n
    }
    let totalSteps = 4

    /// Both photo slots must be filled before we let discovery open.
    var bothPhotosAdded: Bool { photo1 != nil && photo2 != nil }

    func toggle(_ value: String, in set: ReferenceWritableKeyPath<PartnerViewModel, Set<String>>) {
        if self[keyPath: set].contains(value) {
            self[keyPath: set].remove(value)
        } else {
            self[keyPath: set].insert(value)
        }
    }

    func load() async { }
}
