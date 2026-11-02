import SwiftUI

struct VaultItem: Identifiable, Codable, Hashable {
    let id: String
    var product: Product
    var size: String?
    var quantity: Int

    var total: Int { product.price * quantity }

    static func key(productID: String, size: String?) -> String {
        "\(productID.utf8.count):\(productID):\(size ?? "")"
    }
}

struct ShippingAddress: Codable, Hashable {
    var name: String
    var phone: String
    var line: String
    var city: String
    var pincode: String

    var oneLine: String { "\(line), \(city) \(pincode)" }
}

struct Order: Identifiable, Codable, Hashable {
    let id: String
    var items: [VaultItem]
    var total: Int
    var address: ShippingAddress
    var paymentMethod: String
    var paymentStatus: String
    var placedAt: Date
    var status: String

    var paymentMethodID: UUID? = nil

    var paymentLabel: String { paymentMethod == "card" ? "Card" : "UPI" }
    var isPaid: Bool { paymentStatus == "paid" && status != "Cancelled" }
    // Partner membership starts when the order is saved, independently of payment collection.
    var grantsPartnerAccess: Bool {
        !items.isEmpty && status != "Cancelled" &&
        (paymentStatus == "pending" || paymentStatus == "paid")
    }
    var statusLabel: String { paymentStatus == "pending" ? "Payment pending" : status }

    enum CodingKeys: String, CodingKey {
        case id, items, total, status
        case address = "shipping_address", paymentMethod = "payment_method"
        case paymentStatus = "payment_status", placedAt = "placed_at"
        case paymentMethodID = "payment_method_id"
    }
}

struct Ticket: Identifiable, Codable, Hashable {
    let id: String
    var event: Event
    var tier: Pass
    var quantity: Int
    var total: Int
    var paymentStatus: String
    var status: String
    var bookedAt: Date
    var code: String?
    var paymentMethod: String? = nil
    var paymentMethodID: UUID? = nil

    var isActive: Bool { paymentStatus == "paid" && status == "Confirmed" }
    var grantsEventChat: Bool { paymentStatus == "paid" && (status == "Confirmed" || status == "Used") }
    var statusLabel: String { paymentStatus == "pending" ? "Payment pending" : status }

    enum CodingKeys: String, CodingKey {
        case id, event, tier, quantity, total, status, code
        case paymentStatus = "payment_status", bookedAt = "booked_at"
        case paymentMethod = "payment_method", paymentMethodID = "payment_method_id"
    }
}

struct VaultSnapshot {
    var items: [VaultItem]
    var orders: [Order]
    var tickets: [Ticket]
}

@MainActor
@Observable
final class VaultStore {
    private(set) var items: [VaultItem] = []
    private(set) var orders: [Order] = []
    private(set) var tickets: [Ticket] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var loadError: String?
    private(set) var ordersAreCurrent = false
    private(set) var ticketsAreCurrent = false
    private var verifiedOrderIDs: Set<String> = []
    private let service: any CommerceServicing
    private let userID: UUID?
    private let cache: (any PurchaseHistoryCaching)?

    init(userID: UUID? = nil, service: (any CommerceServicing)? = nil,
         cache: (any PurchaseHistoryCaching)? = nil) {
        self.userID = userID
        self.service = service ?? CommerceService(userID: userID)
        self.cache = cache ?? (userID == nil ? nil : FilePurchaseHistoryCache())
        if let userID, let history = try? self.cache?.load(for: userID), history.userID == userID {
            orders = history.orders
            tickets = history.tickets
        }
    }

    var isBusy: Bool { isLoading || isSaving }
    var count: Int { items.reduce(0) { $0 + $1.quantity } }
    var goodsTotal: Int { items.reduce(0) { $0 + $1.total } }
    var hasPartnerAccess: Bool {
        orders.contains { verifiedOrderIDs.contains($0.id) && $0.grantsPartnerAccess } ||
        (ticketsAreCurrent && tickets.contains(where: \.isActive))
    }
    var isShowingSavedOrders: Bool { !ordersAreCurrent && !orders.isEmpty }
    var isShowingSavedTickets: Bool { !ticketsAreCurrent && !tickets.isEmpty }

    func ticket(for eventID: String) -> Ticket? {
        tickets.first { $0.event.id == eventID && $0.status != "Cancelled" }
    }

    func load() async {
        guard !isBusy else { return }
        isLoading = true
        defer { isLoading = false }
        async let cartResult = Self.capture { try await self.service.fetchCart() }
        async let orderResult = Self.capture { try await self.service.fetchOrders() }
        async let ticketResult = Self.capture { try await self.service.fetchTickets() }
        let results = await (cartResult, orderResult, ticketResult)
        guard !Task.isCancelled else { return }
        var failures: [String] = []
        switch results.0 {
        case .success(let savedItems): items = savedItems
        case .failure(let error): failures.append("Vault items: " + error.localizedDescription)
        }
        switch results.1 {
        case .success(let savedOrders):
            orders = savedOrders
            verifiedOrderIDs = Set(savedOrders.map(\.id))
            ordersAreCurrent = true
        case .failure(let error):
            verifiedOrderIDs.removeAll()
            ordersAreCurrent = false
            failures.append("Orders: " + error.localizedDescription)
        }
        switch results.2 {
        case .success(let savedTickets):
            tickets = savedTickets
            ticketsAreCurrent = true
        case .failure(let error):
            ticketsAreCurrent = false
            failures.append("Passes: " + error.localizedDescription)
        }
        loadError = failures.isEmpty ? nil : failures.joined(separator: "\n")
        if ordersAreCurrent || ticketsAreCurrent { saveHistory() }
    }

    private static func capture<Value>(_ action: () async throws -> Value) async -> Result<Value, Error> {
        do { return .success(try await action()) }
        catch { return .failure(error) }
    }

    private func saveHistory() {
        guard let userID else { return }
        try? cache?.save(PurchaseHistory(userID: userID, orders: orders, tickets: tickets))
    }

    func add(_ product: Product, size: String?) async throws {
        let key = VaultItem.key(productID: product.id, size: size)
        let quantity = (items.first { $0.id == key }?.quantity ?? 0) + 1
        try await saveItem(VaultItem(id: key, product: product, size: size, quantity: quantity))
    }

    func increment(_ item: VaultItem) async throws {
        guard let current = items.first(where: { $0.id == item.id }) else { return }
        var updated = current
        updated.quantity += 1
        try await saveItem(updated)
    }

    func decrement(_ item: VaultItem) async throws {
        guard let current = items.first(where: { $0.id == item.id }), current.quantity > 1 else { return }
        var updated = current
        updated.quantity -= 1
        try await saveItem(updated)
    }

    private func saveItem(_ item: VaultItem) async throws {
        guard !isBusy else { throw CommerceError.busy }
        guard (1...99).contains(item.quantity), item.product.price >= 0 else { throw CommerceError.invalidItems }
        isSaving = true
        defer { isSaving = false }
        try await service.saveCartItem(item)
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func remove(_ item: VaultItem) async throws {
        guard !isBusy else { throw CommerceError.busy }
        isSaving = true
        defer { isSaving = false }
        try await service.deleteCartItem(id: item.id)
        items.removeAll { $0.id == item.id }
    }

    /// The server saves the order and removes its Vault items in one transaction.
    /// A stable request ID makes retrying a lost response safe.
    func placeOrder(id: UUID, items checkoutItems: [VaultItem], address: ShippingAddress,
                    paymentMethod: String, fromVault: Bool, paymentMethodID: UUID? = nil) async throws -> Order {
        guard !isBusy else { throw CommerceError.busy }
        guard !checkoutItems.isEmpty else { throw CommerceError.invalidItems }
        isSaving = true
        defer { isSaving = false }
        let order = try await service.placeOrder(id: id, items: checkoutItems, address: address,
                                                 paymentMethod: paymentMethod, fromVault: fromVault,
                                                 paymentMethodID: paymentMethodID)
        orders.removeAll { $0.id == order.id }
        orders.insert(order, at: 0)
        // A successful checkout verifies this row, even if history has not loaded yet.
        verifiedOrderIDs.insert(order.id)
        saveHistory()
        if fromVault {
            let purchasedIDs = Set(order.items.map(\.id))
            items.removeAll { purchasedIDs.contains($0.id) }
        }
        return order
    }

    func bookTicket(id: UUID, event: Event, tier: Pass, paymentMethodID: UUID? = nil) async throws -> Ticket {
        guard !isBusy else { throw CommerceError.busy }
        // Verify with Supabase even when a previous booking is cached locally.
        // The server's unique user/event key makes retries safe.
        isSaving = true
        defer { isSaving = false }
        let ticket = try await service.bookTicket(id: id, event: event, tier: tier, paymentMethodID: paymentMethodID)
        tickets.removeAll { $0.id == ticket.id }
        tickets.insert(ticket, at: 0)
        saveHistory()
        return ticket
    }
}
