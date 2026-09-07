//
//  WishlistStore.swift
//  Raverse-ios
//
//  Shared wishlist state. Injected once at RootView so the Home header, the
//  product detail heart, and the Wishlist screen all read the same saved items.
//

import SwiftUI

@Observable
final class WishlistStore {
    /// Products the raver has hearted, newest first.
    var products: [Product] = []

    var count: Int { products.count }

    func contains(_ product: Product) -> Bool {
        products.contains { $0.id == product.id }
    }

    /// Adds the product if it's new, removes it if it's already saved.
    func toggle(_ product: Product) {
        if contains(product) {
            remove(product)
        } else {
            products.insert(product, at: 0)
        }
    }

    func remove(_ product: Product) {
        products.removeAll { $0.id == product.id }
    }
}
