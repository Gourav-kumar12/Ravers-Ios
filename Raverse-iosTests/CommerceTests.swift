import Foundation
import Testing
@testable import Ravers_ios

@MainActor
struct CommerceTests {
    @Test func bookingRestoresFromServerWithoutLocalCache() async throws {
        let service = CommerceStub()
        let store = VaultStore(service: service)
        let ticket = try await store.bookTicket(id: UUID(), event: event(),
                                               tier: Pass(id: "general", name: "General", price: 799))
        let restarted = VaultStore(service: service)
        #expect(restarted.tickets.isEmpty)
        await restarted.load()
        #expect(restarted.tickets == [ticket])
        #expect(restarted.ticketsAreCurrent)
        #expect(restarted.ticket(for: ticket.event.id) == ticket)
        #expect(!restarted.hasPartnerAccess)
    }

    @Test func bookingCacheSurvivesRestartAndFailedRefreshForSameUserOnly() async throws {
        let service = CommerceStub()
        let cache = HistoryCacheStub()
        let userID = UUID()
        let store = VaultStore(userID: userID, service: service, cache: cache)
        let ticket = try await store.bookTicket(id: UUID(), event: event(),
                                               tier: Pass(id: "general", name: "General", price: 799))
        service.shouldFail = true
        let restarted = VaultStore(userID: userID, service: service, cache: cache)
        await restarted.load()
        #expect(restarted.tickets == [ticket])
        #expect(restarted.isShowingSavedTickets)
        #expect(!restarted.hasPartnerAccess)
        let otherUser = VaultStore(userID: UUID(), service: service, cache: cache)
        #expect(otherUser.tickets.isEmpty)
    }

    @Test func failedBookingDoesNotCreateLocalOrCachedPass() async throws {
        let service = CommerceStub()
        let cache = HistoryCacheStub()
        let userID = UUID()
        let store = VaultStore(userID: userID, service: service, cache: cache)
        service.shouldFail = true
        do {
            _ = try await store.bookTicket(id: UUID(), event: event(),
                                          tier: Pass(id: "general", name: "General", price: 799))
            Issue.record("Expected the failed booking to throw")
        } catch { }
        #expect(store.tickets.isEmpty)
        #expect(cache.values[userID] == nil)
        #expect(!store.isBusy)
    }

    @Test func lostBookingResponseCanRetryWithoutDuplicatePass() async throws {
        let service = CommerceStub()
        let store = VaultStore(service: service)
        let requestID = UUID()
        let tier = Pass(id: "general", name: "General", price: 799)
        service.loseNextTicketResponse = true
        do {
            _ = try await store.bookTicket(id: requestID, event: event(), tier: tier)
            Issue.record("Expected the lost response to throw")
        } catch { }
        #expect(store.tickets.isEmpty)
        #expect(!store.isBusy)
        let ticket = try await store.bookTicket(id: requestID, event: event(), tier: tier)
        #expect(store.tickets == [ticket])
        #expect(service.snapshot.tickets.count == 1)
    }

    @Test func cachedBookingMustStillBeVerifiedBeforeReportingSaveSuccess() async throws {
        let service = CommerceStub()
        let store = VaultStore(service: service)
        let tier = Pass(id: "general", name: "General", price: 799)
        let ticket = try await store.bookTicket(id: UUID(), event: event(), tier: tier)
        service.shouldFail = true
        do {
            _ = try await store.bookTicket(id: UUID(), event: event(), tier: tier)
            Issue.record("A local ticket must not bypass the server")
        } catch { }
        #expect(store.tickets == [ticket])
        #expect(!store.isBusy)
    }

    @Test func restartRestoresSavedOrdersEvenWhenRefreshFails() async throws {
        let service = CommerceStub()
        let cache = HistoryCacheStub()
        let userID = UUID()
        let firstRun = VaultStore(userID: userID, service: service, cache: cache)
        try await firstRun.add(product(), size: "M")
        let order = try await firstRun.placeOrder(id: UUID(), items: firstRun.items, address: address,
                                                  paymentMethod: "upi", fromVault: true)

        // A new store represents a fresh app launch using the same verified user.
        service.shouldFail = true
        let restarted = VaultStore(userID: userID, service: service, cache: cache)
        #expect(restarted.orders == [order])
        #expect(restarted.isShowingSavedOrders)
        await restarted.load()
        #expect(restarted.orders == [order])
        #expect(restarted.loadError != nil)
        #expect(!restarted.hasPartnerAccess)

        let anotherUser = VaultStore(userID: UUID(), service: service, cache: cache)
        #expect(anotherUser.orders.isEmpty)
    }

    @Test func failedTicketLoadDoesNotPreventOrderRestoration() async throws {
        let service = CommerceStub()
        let firstRun = VaultStore(service: service)
        try await firstRun.add(product(), size: nil)
        let order = try await firstRun.placeOrder(id: UUID(), items: firstRun.items, address: address,
                                                  paymentMethod: "card", fromVault: false)
        service.failTicketLoad = true
        let restarted = VaultStore(service: service)
        await restarted.load()
        #expect(restarted.orders == [order])
        #expect(restarted.ordersAreCurrent)
        #expect(restarted.hasPartnerAccess)
        #expect(restarted.loadError?.contains("Passes:") == true)
        #expect(!restarted.isBusy)
    }

    @Test func successfulRefreshReplacesStaleCachedHistory() async throws {
        let service = CommerceStub()
        let cache = HistoryCacheStub()
        let userID = UUID()
        let store = VaultStore(userID: userID, service: service, cache: cache)
        try await store.add(product(), size: nil)
        _ = try await store.placeOrder(id: UUID(), items: store.items, address: address,
                                       paymentMethod: "upi", fromVault: false)
        service.snapshot.orders = []
        let restarted = VaultStore(userID: userID, service: service, cache: cache)
        #expect(restarted.orders.count == 1)
        await restarted.load()
        #expect(restarted.orders.isEmpty)
        #expect(restarted.ordersAreCurrent)
        #expect(!restarted.hasPartnerAccess)
        #expect(cache.values[userID]?.orders.isEmpty == true)
    }

    @Test func fileCacheIsPersistentAndSeparatedByAccount() async throws {
        let service = CommerceStub()
        let userID = UUID()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultStore(userID: userID, service: service, cache: FilePurchaseHistoryCache(directory: directory))
        try await store.add(product(), size: nil)
        let order = try await store.placeOrder(id: UUID(), items: store.items, address: address,
                                               paymentMethod: "upi", fromVault: false)
        let reopenedCache = FilePurchaseHistoryCache(directory: directory)
        #expect(try reopenedCache.load(for: userID)?.orders == [order])
        #expect(try reopenedCache.load(for: UUID()) == nil)
    }

    @Test(arguments: ["pending", "paid"])
    func cachedOrderDoesNotUnlockPartnerBeforeServerRefresh(_ paymentStatus: String) async throws {
        let service = CommerceStub()
        let cache = HistoryCacheStub()
        let userID = UUID()
        let firstRun = VaultStore(userID: userID, service: service, cache: cache)
        try await firstRun.add(product(), size: nil)
        var order = try await firstRun.placeOrder(id: UUID(), items: firstRun.items, address: address,
                                                   paymentMethod: "upi", fromVault: false)
        order.paymentStatus = paymentStatus
        order.status = "Confirmed"
        cache.values[userID] = PurchaseHistory(userID: userID, orders: [order], tickets: [])
        let restarted = VaultStore(userID: userID, service: service, cache: cache)
        #expect(restarted.orders == [order])
        #expect(!restarted.hasPartnerAccess)
        service.snapshot.orders = [order]
        await restarted.load()
        #expect(restarted.hasPartnerAccess)
    }

    @Test func failedOrderDoesNotUnlockPartner() async {
        let service = CommerceStub()
        let store = VaultStore(service: service)
        service.shouldFail = true
        let item = VaultItem(id: "test", product: product(), size: nil, quantity: 1)
        do {
            _ = try await store.placeOrder(id: UUID(), items: [item], address: address,
                                           paymentMethod: "upi", fromVault: false)
            Issue.record("Expected the failed checkout to throw")
        } catch { }
        #expect(store.orders.isEmpty)
        #expect(!store.hasPartnerAccess)
    }

    @Test(arguments: ["failed", "refunded", "cancelled", "empty"])
    func ineligibleOrderDoesNotUnlockPartnerAfterRefresh(_ scenario: String) async throws {
        let service = CommerceStub()
        let store = VaultStore(service: service)
        try await store.add(product(), size: nil)
        _ = try await store.placeOrder(id: UUID(), items: store.items, address: address,
                                       paymentMethod: "upi", fromVault: false)
        #expect(store.hasPartnerAccess)
        if scenario == "cancelled" {
            service.snapshot.orders[0].status = "Cancelled"
        } else if scenario == "empty" {
            service.snapshot.orders[0].items = []
        } else {
            service.snapshot.orders[0].paymentStatus = scenario
        }
        await store.load()
        #expect(!store.hasPartnerAccess)
    }

    @Test func savingAnIneligibleOrderDoesNotValidateCachedOrders() async throws {
        let service = CommerceStub()
        let cache = HistoryCacheStub()
        let userID = UUID()
        let firstRun = VaultStore(userID: userID, service: service, cache: cache)
        try await firstRun.add(product(), size: nil)
        let cachedOrder = try await firstRun.placeOrder(id: UUID(), items: firstRun.items, address: address,
                                                       paymentMethod: "upi", fromVault: false)
        let restarted = VaultStore(userID: userID, service: service, cache: cache)
        #expect(!restarted.hasPartnerAccess)
        let item = VaultItem(id: "test", product: product(), size: nil, quantity: 1)
        // Retrying a different existing order must not validate the cached eligible row.
        let refundedID = UUID()
        let refundedOrder = Order(id: refundedID.uuidString, items: [item], total: item.total,
                                  address: address, paymentMethod: "upi", paymentStatus: "refunded",
                                  placedAt: .now, status: "Placed")
        service.snapshot.orders = [refundedOrder]
        _ = try await restarted.placeOrder(id: refundedID,
                                           items: [item], address: address,
                                           paymentMethod: "upi", fromVault: false)
        #expect(restarted.orders.contains(cachedOrder))
        #expect(!restarted.hasPartnerAccess)
    }

    @Test func failedCartWriteDoesNotShowAnAddedItem() async throws {
        let service = CommerceStub()
        let store = VaultStore(service: service)
        service.shouldFail = true
        do {
            try await store.add(product(), size: "M")
            Issue.record("A failed write must throw")
        } catch { }
        #expect(store.items.isEmpty)
        #expect(!store.isBusy)
        service.shouldFail = false
        try await store.add(product(), size: "M")
        let restored = VaultStore(service: service)
        await restored.load()
        #expect(restored.items == store.items)
        #expect(restored.count == 1)
    }

    @Test func vaultCheckoutIncludesAllItemsAndRestoresHistory() async throws {
        let service = CommerceStub()
        let store = VaultStore(service: service)
        try await store.add(product(), size: "M")
        try await store.add(product(id: "second", price: 2000), size: "L")
        try await store.increment(store.items[1])
        let order = try await store.placeOrder(id: UUID(), items: store.items, address: address,
                                                paymentMethod: "upi", fromVault: true)
        #expect(order.items.count == 2)
        #expect(order.total == 5000)
        #expect(store.items.isEmpty)
        #expect(order.paymentStatus == "pending")
        #expect(store.hasPartnerAccess)
        let restored = VaultStore(service: service)
        await restored.load()
        #expect(restored.orders == [order])
        #expect(restored.items.isEmpty)
        #expect(restored.hasPartnerAccess)
    }

    @Test func directCheckoutDoesNotRemoveVaultItems() async throws {
        let service = CommerceStub()
        let store = VaultStore(service: service)
        try await store.add(product(), size: "M")
        let items = store.items
        _ = try await store.placeOrder(id: UUID(), items: items, address: address,
                                       paymentMethod: "card", fromVault: false)
        #expect(store.items == items)
        #expect(service.snapshot.items == items)
        #expect(store.hasPartnerAccess)
    }

    @Test func lostOrderResponseCanRetryWithoutDuplicatingTheOrder() async throws {
        let service = CommerceStub()
        let store = VaultStore(service: service)
        try await store.add(product(), size: nil)
        let items = store.items
        let requestID = UUID()
        service.loseNextOrderResponse = true
        do {
            _ = try await store.placeOrder(id: requestID, items: items, address: address,
                                           paymentMethod: "upi", fromVault: true)
            Issue.record("The simulated lost response must throw")
        } catch { }
        #expect(store.orders.isEmpty)
        #expect(store.items == items)
        #expect(!store.hasPartnerAccess)
        #expect(!store.isBusy)
        let order = try await store.placeOrder(id: requestID, items: items, address: address,
                                                paymentMethod: "upi", fromVault: true)
        #expect(store.orders == [order])
        #expect(service.snapshot.orders.count == 1)
        #expect(store.items.isEmpty)
        #expect(store.hasPartnerAccess)
    }

    @Test func failedRemovalKeepsTheCartItem() async throws {
        let service = CommerceStub()
        let store = VaultStore(service: service)
        try await store.add(product(), size: "S")
        let item = store.items[0]
        service.shouldFail = true
        do { try await store.remove(item); Issue.record("Expected failure") } catch { }
        #expect(store.items == [item])
        #expect(!store.isBusy)
    }

    @Test func duplicateTicketTapDoesNotCreateAnotherBookingOrUnlockPartner() async throws {
        let service = CommerceStub()
        let store = VaultStore(service: service)
        let event = event()
        let tier = Pass(id: "general", name: "General", price: 799)
        service.shouldFail = true
        do {
            _ = try await store.bookTicket(id: UUID(), event: event, tier: tier)
            Issue.record("Expected failure")
        } catch { }
        #expect(store.tickets.isEmpty)
        service.shouldFail = false
        let ticket = try await store.bookTicket(id: UUID(), event: event, tier: tier)
        let repeated = try await store.bookTicket(id: UUID(), event: event, tier: tier)
        #expect(ticket == repeated)
        #expect(store.tickets.count == 1)
        #expect(!store.hasPartnerAccess)
        service.snapshot.tickets[0].paymentStatus = "paid"
        service.snapshot.tickets[0].status = "Confirmed"
        await store.load()
        #expect(store.hasPartnerAccess)
    }

    @Test func invalidQuantityIsNotSentAndCartKeysDoNotCollide() async throws {
        let service = CommerceStub()
        let item = VaultItem(id: "max", product: product(), size: "M", quantity: 99)
        service.snapshot.items = [item]
        let store = VaultStore(service: service)
        await store.load()
        do { try await store.increment(item); Issue.record("Expected quantity limit") } catch { }
        #expect(service.snapshot.items == [item])
        #expect(store.items == [item])
        #expect(VaultItem.key(productID: "a:b", size: "c") != VaultItem.key(productID: "a", size: "b:c"))
    }

    private func product(id: String = "hoodie", price: Int = 1000) -> Product {
        Product(id: id, name: id, category: "APPAREL", price: price, isPartnerKey: true, imageName: "hoody")
    }

    private var address: ShippingAddress {
        ShippingAddress(name: "Test Customer", phone: "9876543210", line: "Test street", city: "Noida", pincode: "201301")
    }

    private func event() -> Event {
        Event(id: "test-event", name: "Test event", venue: "Test venue", city: "Noida",
              date: .now.addingTimeInterval(86400), genres: [], fromPrice: 799, imageName: "party-1", passes: [])
    }
}

@MainActor
private final class CommerceStub: CommerceServicing {
    var snapshot = VaultSnapshot(items: [], orders: [], tickets: [])
    var shouldFail = false
    var loseNextOrderResponse = false
    var loseNextTicketResponse = false
    var failTicketLoad = false

    private func checkFailure() throws {
        if shouldFail { throw CommerceError.unavailable }
    }

    func fetchCart() async throws -> [VaultItem] { try checkFailure(); return snapshot.items }
    func fetchOrders() async throws -> [Order] { try checkFailure(); return snapshot.orders }
    func fetchTickets() async throws -> [Ticket] {
        try checkFailure()
        if failTicketLoad { throw CommerceError.unavailable }
        return snapshot.tickets
    }

    func saveCartItem(_ item: VaultItem) async throws {
        try checkFailure()
        snapshot.items.removeAll { $0.id == item.id }
        snapshot.items.append(item)
    }

    func deleteCartItem(id: String) async throws {
        try checkFailure()
        snapshot.items.removeAll { $0.id == id }
    }

    func placeOrder(id: UUID, items: [VaultItem], address: ShippingAddress,
                    paymentMethod: String, fromVault: Bool, paymentMethodID: UUID?) async throws -> Order {
        try checkFailure()
        if let existing = snapshot.orders.first(where: { $0.id == id.uuidString }) { return existing }
        let order = Order(id: id.uuidString, items: items, total: items.reduce(0) { $0 + $1.total },
                          address: address, paymentMethod: paymentMethod, paymentStatus: "pending",
                          placedAt: .now, status: "Placed")
        snapshot.orders.insert(order, at: 0)
        if fromVault { snapshot.items.removeAll { item in items.contains { $0.id == item.id } } }
        if loseNextOrderResponse {
            loseNextOrderResponse = false
            throw URLError(.networkConnectionLost)
        }
        return order
    }

    func bookTicket(id: UUID, event: Event, tier: Pass, paymentMethodID: UUID?) async throws -> Ticket {
        try checkFailure()
        if let existing = snapshot.tickets.first(where: { $0.event.id == event.id }) { return existing }
        let ticket = Ticket(id: id.uuidString, event: event, tier: tier, quantity: 1, total: tier.price,
                            paymentStatus: "pending", status: "Pending", bookedAt: .now)
        snapshot.tickets.insert(ticket, at: 0)
        if loseNextTicketResponse {
            loseNextTicketResponse = false
            throw URLError(.networkConnectionLost)
        }
        return ticket
    }
}

@MainActor
private final class HistoryCacheStub: PurchaseHistoryCaching {
    var values: [UUID: PurchaseHistory] = [:]
    func load(for userID: UUID) throws -> PurchaseHistory? { values[userID] }
    func save(_ history: PurchaseHistory) throws { values[history.userID] = history }
}
