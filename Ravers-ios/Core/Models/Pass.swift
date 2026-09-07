//
//  Pass.swift
//  Raverse-ios
//
//  A ticket tier for an event (Phase 1, Phase 2, Frequency Tier, ...).
//

import Foundation

struct Pass: Identifiable, Codable, Hashable {
    let id: String
    var name: String            // "Phase 1"
    var detail: String?         // "Entry", "Fast lane, mezzanine, cloakroom"
    var price: Int
    var remaining: Int?         // nil = unlimited / not shown
}
