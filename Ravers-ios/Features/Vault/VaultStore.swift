

import SwiftUI

struct VaultItem: Identifiable, Hashable {
    let id: String
    var product: Product
    var size: String?
    var quantity: Int
}

/// Where an order ships to. Collected on the Address screen during checkout.
struct ShippingAddress: Hashable {
    var name: String
    var phone: String
    var line: String
    var city: String
    var pincode: String

    /// A one-line summary shown on the order card.
    var oneLine: String { "\(line), \(city) \(pincode)" }
}

/// A placed order, shown under the Vault's ORDERS tab.
struct Order: Identifiable, Hashable {
    let id: String
    var product: Product
    var size: String?
    var quantity: Int
    var total: Int
    var address: ShippingAddress
    var paymentLabel: String   // "UPI · name@bank" or "Card •••• 4291"
    var placedAt: Date
    var status: String         // "Placed", "Shipped", …
}

@Observable
final class VaultStore {
    var items: [VaultItem] = []
    /// Placed orders, newest first — surfaced in the Vault ORDERS tab.
    var orders: [Order] = []
    /// True once the user has booked at least one party pass.
    var hasBookedTicket = false

    var count: Int { items.reduce(0) { $0 + $1.quantity } }

    /// The Partner (Rave Sync) tab unlocks once the user has committed to the
    /// scene — either by buying a product or booking a party pass. Until then
    /// the tab shows the Ravers Plus paywall instead.
    var hasPartnerAccess: Bool { !orders.isEmpty || hasBookedTicket }

    /// Records a completed order at the top of the ORDERS list.
    func placeOrder(_ order: Order) {
        orders.insert(order, at: 0)
    }

    /// Records that the user booked a party pass (unlocks Partner access).
    func bookTicket() {
        hasBookedTicket = true
    }

    var goodsTotal: Int { items.reduce(0) { $0 + $1.product.price * $1.quantity } }

    func add(_ product: Product, size: String?) {
        let key = product.id + "-" + (size ?? "-")
        if let index = items.firstIndex(where: { $0.id == key }) {
            items[index].quantity += 1
        } else {
            items.append(VaultItem(id: key, product: product, size: size, quantity: 1))
        }
    }

    func increment(_ item: VaultItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].quantity += 1
    }

    func decrement(_ item: VaultItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].quantity = max(1, items[index].quantity - 1)
    }

    func remove(_ item: VaultItem) {
        items.removeAll { $0.id == item.id }
    }
}
