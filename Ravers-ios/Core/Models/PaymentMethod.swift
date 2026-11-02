import Foundation

/// Preferences, not a chargeable payment instrument. No PAN, CVV or UPI PIN is represented.
struct PaymentMethod: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case upi, card
        var id: String { rawValue }
        var title: String { self == .upi ? "UPI" : "Card" }
        var icon: String { self == .upi ? "indianrupeesign.circle" : "creditcard" }
    }
    var id: UUID
    var kind: Kind
    var upiID: String?
    var cardholderName: String?
    var cardBrand: String?
    var cardLastFour: String?
    var expiryMonth: Int?
    var expiryYear: Int?

    var label: String { kind == .upi ? (upiID ?? "UPI") : "\(cardBrand ?? "Card") •••• \(cardLastFour ?? "")" }
    var detail: String {
        if kind == .upi { return "UPI preference" }
        return "\(cardholderName ?? "") · \(String(format: "%02d", expiryMonth ?? 0))/\(expiryYear ?? 0) · Preference only"
    }
    enum CodingKeys: String, CodingKey {
        case id, kind
        case upiID = "upi_id", cardholderName = "cardholder_name", cardBrand = "card_brand"
        case cardLastFour = "card_last_four", expiryMonth = "expiry_month", expiryYear = "expiry_year"
    }
}

struct PaymentMethodDraft {
    var id = UUID()
    var kind: PaymentMethod.Kind = .upi
    var upiID = ""
    var cardholderName = ""
    var cardBrand = "Visa"
    var cardLastFour = ""
    var expiryMonth = ""
    var expiryYear = ""
    static let brands = ["Visa", "Mastercard", "RuPay", "Amex", "Other"]

    init(method: PaymentMethod? = nil) {
        guard let method else { return }
        id = method.id; kind = method.kind; upiID = method.upiID ?? ""
        cardholderName = method.cardholderName ?? ""; cardBrand = method.cardBrand ?? "Visa"
        cardLastFour = method.cardLastFour ?? ""
        expiryMonth = method.expiryMonth.map(String.init) ?? ""
        expiryYear = method.expiryYear.map(String.init) ?? ""
    }
    func value(at date: Date = .now) throws -> PaymentMethod {
        if kind == .upi {
            let clean = upiID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard clean.range(of: "^[a-z0-9._-]{1,256}@[a-z][a-z0-9.-]{1,63}$", options: .regularExpression) != nil else {
                throw PaymentPreferenceError.invalidUPI
            }
            return PaymentMethod(id: id, kind: .upi, upiID: clean)
        }
        let name = cardholderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMonth = expiryMonth.trimmingCharacters(in: .whitespaces)
        let cleanYear = expiryYear.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name.count <= 100, Self.brands.contains(cardBrand),
              cardLastFour.count == 4, cardLastFour.allSatisfy({ $0.isASCII && $0.isNumber }),
              let month = Int(cleanMonth), (1...12).contains(month),
              let year = Int(cleanYear), (2026...2100).contains(year) else {
            throw PaymentPreferenceError.invalidCard
        }
        let current = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        guard year * 12 + month >= (current.year ?? 2026) * 12 + (current.month ?? 1) else {
            throw PaymentPreferenceError.expiredCard
        }
        return PaymentMethod(id: id, kind: .card, cardholderName: name, cardBrand: cardBrand,
                             cardLastFour: cardLastFour, expiryMonth: month, expiryYear: year)
    }
}

enum PaymentPreferenceError: LocalizedError {
    case invalidUPI, invalidCard, expiredCard, busy, notAuthenticated, unavailable
    var errorDescription: String? {
        switch self {
        case .invalidUPI: "Enter a valid UPI ID, such as name@bank."
        case .invalidCard: "Enter the name, card network, last four digits and expiry year (YYYY)."
        case .expiredCard: "This card has expired. Update its expiry or choose another preference."
        case .busy: "Payment preferences are updating. Please try again in a moment."
        case .notAuthenticated: "Sign in again to manage payment preferences."
        case .unavailable: "Couldn't update your payment preferences. Please try again."
        }
    }
}
