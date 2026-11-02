import Foundation
import Supabase

@MainActor
protocol CommerceServicing {
    func fetchCart() async throws -> [VaultItem]
    func fetchOrders() async throws -> [Order]
    func fetchTickets() async throws -> [Ticket]
    func saveCartItem(_ item: VaultItem) async throws
    func deleteCartItem(id: String) async throws
    func placeOrder(id: UUID, items: [VaultItem], address: ShippingAddress,
                    paymentMethod: String, fromVault: Bool, paymentMethodID: UUID?) async throws -> Order
    func bookTicket(id: UUID, event: Event, tier: Pass, paymentMethodID: UUID?) async throws -> Ticket
}

enum CommerceError: LocalizedError {
    case notAuthenticated, busy, invalidItems, unavailable
    case diagnostic(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Sign in again before updating your Vault or placing a booking."
        case .busy: "Your Vault is updating. Please try again in a moment."
        case .invalidItems: "Check the selected items and quantities, then try again."
        case .unavailable: "We couldn't save your request. Please try again later."
        case .diagnostic(let message): message
        }
    }
}

/// Stores purchase requests; only a trusted payment backend can mark them paid.
/// Card numbers, expiry dates and UPI addresses are never sent to these tables.
@MainActor
final class CommerceService: CommerceServicing {
    private let expectedUserID: UUID?

    init(userID: UUID? = nil) {
        expectedUserID = userID
    }

    private func authenticatedClient() async throws -> (SupabaseClient, UUID) {
        let client = try SupabaseManager.shared.makeClient()
        let session = try await client.auth.session
        guard AuthService.isVerifiedEmailUser(session.user) else { throw CommerceError.notAuthenticated }
        if let expectedUserID, session.user.id != expectedUserID { throw CommerceError.notAuthenticated }
        return (client, session.user.id)
    }

    private func checkOwner(_ userID: UUID, client: SupabaseClient) throws {
        guard client.auth.currentUser?.id == userID else { throw CommerceError.notAuthenticated }
    }

    func fetchCart() async throws -> [VaultItem] {
        do {
            let (client, userID) = try await authenticatedClient()
            let rows: [CartRow] = try await client.from("vault_items").select()
                .eq("user_id", value: userID.uuidString).order("created_at").execute().value
            try checkOwner(userID, client: client)
            return rows.map(\.item)
        } catch { throw mapped(error) }
    }

    func fetchOrders() async throws -> [Order] {
        do {
            let (client, userID) = try await authenticatedClient()
            let orders: [Order] = try await client.from("orders").select()
                .eq("user_id", value: userID.uuidString).order("placed_at", ascending: false).execute().value
            try checkOwner(userID, client: client)
            return orders
        } catch { throw mapped(error) }
    }

    func fetchTickets() async throws -> [Ticket] {
        do {
            let (client, userID) = try await authenticatedClient()
            let tickets: [Ticket] = try await client.from("tickets").select()
                .eq("user_id", value: userID.uuidString).order("booked_at", ascending: false).execute().value
            try checkOwner(userID, client: client)
            return tickets
        } catch { throw mapped(error) }
    }

    func saveCartItem(_ item: VaultItem) async throws {
        do {
            let (client, userID) = try await authenticatedClient()
            try await client.from("vault_items").upsert(CartRow(userID: userID, item: item),
                                                        onConflict: "user_id,id").execute()
            try checkOwner(userID, client: client)
        } catch { throw mapped(error) }
    }

    func deleteCartItem(id: String) async throws {
        do {
            let (client, userID) = try await authenticatedClient()
            try await client.from("vault_items").delete()
                .eq("user_id", value: userID.uuidString).eq("id", value: id).execute()
            try checkOwner(userID, client: client)
        } catch { throw mapped(error) }
    }

    func placeOrder(id: UUID, items: [VaultItem], address: ShippingAddress,
                    paymentMethod: String, fromVault: Bool, paymentMethodID: UUID?) async throws -> Order {
        do {
            let (client, userID) = try await authenticatedClient()
            #if DEBUG
            let host = (Bundle.main.infoDictionary?["SUPABASE_URL"] as? String)
                .flatMap { URL(string: $0)?.host } ?? "unknown project"
            print("[CommerceService] Sending order \(id.uuidString.lowercased()) to \(host)")
            #endif
            let order: Order
            if let paymentMethodID {
                order = try await client.rpc("place_product_order_with_payment", params: OrderPreferenceRequest(
                    id: id, items: items, address: address, fromVault: fromVault, methodID: paymentMethodID
                )).single().execute().value
            } else {
                order = try await client.rpc("place_product_order", params: OrderRequest(
                    id: id, items: items, address: address, paymentMethod: paymentMethod, fromVault: fromVault
                )).single().execute().value
            }
            guard UUID(uuidString: order.id) == id else { throw CommerceError.unavailable }
            // Read the actual table before confirming, so a successful checkout
            // always has a persisted row the customer/admin can look up by ID.
            let persisted: Order = try await client.from("orders").select()
                .eq("id", value: id.uuidString).eq("user_id", value: userID.uuidString)
                .single().execute().value
            try checkOwner(userID, client: client)
            #if DEBUG
            print("[CommerceService] Verified saved order \(persisted.id) in \(host)")
            #endif
            return persisted
        } catch { throw mapped(error) }
    }

    func bookTicket(id: UUID, event: Event, tier: Pass, paymentMethodID: UUID?) async throws -> Ticket {
        do {
            let (client, userID) = try await authenticatedClient()
            #if DEBUG
            let host = (Bundle.main.infoDictionary?["SUPABASE_URL"] as? String)
                .flatMap { URL(string: $0)?.host } ?? "unknown project"
            print("[CommerceService] Sending ticket \(id.uuidString.lowercased()) to \(host)")
            #endif
            var snapshot = event
            snapshot.heldPass = nil
            if let paymentMethodID {
                let _: [Ticket] = try await client.rpc("book_event_ticket_with_payment", params: TicketPreferenceRequest(
                    id: id, event: snapshot, tier: tier, methodID: paymentMethodID
                )).execute().value
            } else {
                try await client.from("tickets").upsert(TicketRequest(
                    id: id, userID: userID, eventID: event.id, event: snapshot, tier: tier,
                    quantity: 1, total: tier.price
                ), onConflict: "user_id,event_id", ignoreDuplicates: true).execute()
            }
            let ticket: Ticket = try await client.from("tickets").select()
                .eq("user_id", value: userID.uuidString).eq("event_id", value: event.id)
                .single().execute().value
            try checkOwner(userID, client: client)
            guard ticket.event.id == event.id else { throw CommerceError.unavailable }
            #if DEBUG
            print("[CommerceService] Verified saved ticket \(ticket.id) in \(host)")
            #endif
            return ticket
        } catch { throw mapped(error) }
    }

    private func mapped(_ error: Error) -> Error {
        if error is CommerceError { return error }
        if error is URLError {
            return NSError(domain: "Raverse.Commerce", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Couldn't connect. Check your internet connection and try again."
            ])
        }
        #if DEBUG
        print("[CommerceService] \(error.localizedDescription)")
        if let databaseError = error as? PostgrestError {
            return CommerceError.diagnostic("Purchase service error \(databaseError.code ?? "unknown"): \(databaseError.message)")
        }
        if error is DecodingError {
            return CommerceError.diagnostic("The server response couldn't be read. See the [CommerceService] error in Xcode's console.")
        }
        #endif
        return CommerceError.unavailable
    }
}

private struct CartRow: Codable {
    let userID: UUID
    let id: String
    let product: Product
    let size: String?
    let quantity: Int

    init(userID: UUID, item: VaultItem) {
        self.userID = userID
        id = item.id
        product = item.product
        size = item.size
        quantity = item.quantity
    }

    var item: VaultItem { VaultItem(id: id, product: product, size: size, quantity: quantity) }
    enum CodingKeys: String, CodingKey { case userID = "user_id", id, product, size, quantity }
}

private struct OrderRequest: Encodable {
    let id: UUID
    let items: [VaultItem]
    let address: ShippingAddress
    let paymentMethod: String
    let fromVault: Bool

    enum CodingKeys: String, CodingKey {
        case id = "p_id", items = "p_items", address = "p_address"
        case paymentMethod = "p_payment_method", fromVault = "p_from_vault"
    }
}

private struct TicketRequest: Encodable {
    let id: UUID
    let userID: UUID
    let eventID: String
    let event: Event
    let tier: Pass
    let quantity: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case id, event, tier, quantity, total
        case userID = "user_id", eventID = "event_id"
    }
}

private struct OrderPreferenceRequest: Encodable {
    let id: UUID
    let items: [VaultItem]
    let address: ShippingAddress
    let fromVault: Bool
    let methodID: UUID
    enum CodingKeys: String, CodingKey {
        case id = "p_id", items = "p_items", address = "p_address"
        case fromVault = "p_from_vault", methodID = "p_method"
    }
}

private struct TicketPreferenceRequest: Encodable {
    let id: UUID
    let event: Event
    let tier: Pass
    let methodID: UUID
    enum CodingKeys: String, CodingKey {
        case id = "p_id", event = "p_event", tier = "p_tier", methodID = "p_method"
    }
}
