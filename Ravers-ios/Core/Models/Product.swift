//
//  Product.swift
//  Raverse-ios
//
//  A catalog item (merch or hardware). Codable so it can decode from Supabase.
//

import Foundation

struct Product: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var category: String        // e.g. "HARDWARE", "TOPS"
    var price: Int              // in rupees
    var compareAtPrice: Int?    // original/strikethrough price, if on sale
    var isPartnerKey: Bool      // unlocks Partner features when owned
    var imageName: String       // asset name or remote URL
    var description: String?
    var sizes: [String]? = nil  // selectable sizes, e.g. ["S","M","L","XL"]
    var specs: [String]? = nil  // CONFIGURATION spec chips shown on detail
}
