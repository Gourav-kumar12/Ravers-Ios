import Foundation
import Testing
@testable import Ravers_ios

@MainActor
struct PaymentPreferenceTests {
    @Test func upiIsNormalizedAndContainsNoCardData() throws {
        var draft = PaymentMethodDraft()
        draft.upiID = "  Raver.Name@OKBank \n"
        let method = try draft.value()
        #expect(method.upiID == "raver.name@okbank")
        #expect(method.cardLastFour == nil)
        #expect(method.cardholderName == nil)
    }
    @Test(arguments: ["", "name", "name@", "@bank", "name @bank", "name@@bank", "name@b", "नाम@bank"])
    func invalidUPIIsRejected(_ value: String) {
        var draft = PaymentMethodDraft()
        draft.upiID = value
        #expect(throws: PaymentPreferenceError.self) { try draft.value() }
    }
    @Test func cardKeepsOnlyLastFourAndRejectsFullNumberOrExpiredDate() throws {
        var draft = validCard()
        let method = try draft.value(at: Date(timeIntervalSince1970: 1793404800))
        let encoded = String(decoding: try JSONEncoder().encode(method), as: UTF8.self)
        #expect(method.cardLastFour == "1234")
        #expect(!encoded.contains("card_number"))
        #expect(!encoded.contains("cvv"))
        #expect(method.upiID == nil)
        draft.cardLastFour = "4111111111111234"
        #expect(throws: PaymentPreferenceError.self) { try draft.value() }
        draft.cardLastFour = "1234"
        draft.expiryMonth = "9"; draft.expiryYear = "2026"
        #expect(throws: PaymentPreferenceError.self) { try draft.value(at: Date(timeIntervalSince1970: 1793404800)) }
    }
    @Test func saveEditReloadAndDeleteUseServerConfirmedValues() async throws {
        let service = PaymentStub()
        let store = PaymentMethodStore(service: service)
        var draft = PaymentMethodDraft()
        draft.upiID = "raver@bank"
        let saved = try await store.save(draft)
        #expect(store.methods == [saved])
        var edit = PaymentMethodDraft(method: saved)
        edit.upiID = "updated@bank"
        _ = try await store.save(edit)
        #expect(store.methods.count == 1)
        #expect(store.methods[0].upiID == "updated@bank")
        let restarted = PaymentMethodStore(service: service)
        await restarted.load()
        #expect(restarted.methods == store.methods)
        await restarted.delete(restarted.methods[0])
        #expect(restarted.methods.isEmpty)
        #expect(service.methods.isEmpty)
    }
    @Test func failedSaveAndDeleteDoNotInventOrRemoveMethods() async throws {
        let service = PaymentStub()
        let store = PaymentMethodStore(service: service)
        var draft = PaymentMethodDraft()
        draft.upiID = "raver@bank"
        service.fail = true
        do { _ = try await store.save(draft); Issue.record("Expected failure") } catch { }
        #expect(store.methods.isEmpty)
        service.fail = false
        let method = try await store.save(draft)
        service.fail = true
        await store.delete(method)
        #expect(store.methods == [method])
        #expect(store.errorMessage != nil)
        #expect(!store.isBusy)
    }
    @Test func checkoutUsesSavedPreferenceWithoutDuplicatingIt() async throws {
        let service = PaymentStub()
        let store = PaymentMethodStore(service: service)
        var draft = PaymentMethodDraft()
        draft.upiID = "raver@bank"
        let saved = try await store.resolve(selectedID: nil, draft: draft)
        let reused = try await store.resolve(selectedID: saved.id, draft: PaymentMethodDraft())
        #expect(reused == saved)
        #expect(service.saves == 1)
        #expect(store.methods.count == 1)
    }
    private func validCard() -> PaymentMethodDraft {
        var draft = PaymentMethodDraft()
        draft.kind = .card; draft.cardholderName = "Test Raver"
        draft.cardLastFour = "1234"; draft.expiryMonth = "12"; draft.expiryYear = "2030"
        return draft
    }
}

@MainActor
private final class PaymentStub: PaymentMethodServicing {
    var methods: [PaymentMethod] = []
    var fail = false
    var saves = 0
    func fetch() async throws -> [PaymentMethod] {
        if fail { throw PaymentPreferenceError.unavailable }; return methods
    }
    func save(_ method: PaymentMethod) async throws -> PaymentMethod {
        if fail { throw PaymentPreferenceError.unavailable }
        saves += 1
        methods.removeAll { $0.id == method.id }; methods.append(method)
        return method
    }
    func delete(id: UUID) async throws {
        if fail { throw PaymentPreferenceError.unavailable }
        methods.removeAll { $0.id == id }
    }
}
