import Foundation
import Supabase

@MainActor
protocol PaymentMethodServicing {
    func fetch() async throws -> [PaymentMethod]
    func save(_ method: PaymentMethod) async throws -> PaymentMethod
    func delete(id: UUID) async throws
}

@MainActor
final class PaymentMethodService: PaymentMethodServicing {
    private let expectedUserID: UUID?
    init(userID: UUID? = nil) { expectedUserID = userID }
    private func client() async throws -> (SupabaseClient, UUID) {
        let client = try SupabaseManager.shared.makeClient()
        let session = try await client.auth.session
        guard AuthService.isVerifiedEmailUser(session.user),
              expectedUserID == nil || expectedUserID == session.user.id else {
            throw PaymentPreferenceError.notAuthenticated
        }
        return (client, session.user.id)
    }
    private func checkOwner(_ userID: UUID, client: SupabaseClient) throws {
        guard client.auth.currentUser?.id == userID else { throw PaymentPreferenceError.notAuthenticated }
    }
    func fetch() async throws -> [PaymentMethod] {
        let (client, userID) = try await client()
        let rows: [PaymentMethod] = try await client.from("payment_methods").select()
            .eq("user_id", value: userID.uuidString).order("created_at", ascending: false).execute().value
        try checkOwner(userID, client: client)
        return rows
    }
    func save(_ method: PaymentMethod) async throws -> PaymentMethod {
        let (client, userID) = try await client()
        let valid = try PaymentMethodDraft(method: method).value()
        let row = MethodWrite(userID: userID, method: valid)
        // Explicit nulls clear the fields belonging to the other kind on edits.
        try await client.from("payment_methods").upsert(row).execute()
        let saved: PaymentMethod = try await client.from("payment_methods").select()
            .eq("id", value: valid.id.uuidString).eq("user_id", value: userID.uuidString)
            .single().execute().value
        try checkOwner(userID, client: client)
        return saved
    }
    func delete(id: UUID) async throws {
        let (client, userID) = try await client()
        try await client.from("payment_methods").delete()
            .eq("id", value: id.uuidString).eq("user_id", value: userID.uuidString).execute()
        try checkOwner(userID, client: client)
    }
}

/// An explicit payload allowlist; full card numbers, CVVs and UPI PINs cannot be encoded.
private struct MethodWrite: Encodable {
    let userID: UUID
    let method: PaymentMethod
    enum CodingKeys: String, CodingKey {
        case id, kind
        case userID = "user_id", upiID = "upi_id", cardholderName = "cardholder_name"
        case cardBrand = "card_brand", cardLastFour = "card_last_four"
        case expiryMonth = "expiry_month", expiryYear = "expiry_year"
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(method.id, forKey: .id)
        try values.encode(userID, forKey: .userID)
        try values.encode(method.kind, forKey: .kind)
        try values.encode(method.upiID, forKey: .upiID)
        try values.encode(method.cardholderName, forKey: .cardholderName)
        try values.encode(method.cardBrand, forKey: .cardBrand)
        try values.encode(method.cardLastFour, forKey: .cardLastFour)
        try values.encode(method.expiryMonth, forKey: .expiryMonth)
        try values.encode(method.expiryYear, forKey: .expiryYear)
    }
}
