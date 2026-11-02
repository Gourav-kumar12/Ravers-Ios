import SwiftUI

@MainActor
@Observable
final class PaymentMethodStore {
    private(set) var methods: [PaymentMethod] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private let service: any PaymentMethodServicing

    init(userID: UUID? = nil, service: (any PaymentMethodServicing)? = nil) {
        self.service = service ?? PaymentMethodService(userID: userID)
    }
    var isBusy: Bool { isLoading || isSaving }
    func load() async {
        guard !isBusy else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let saved = try await service.fetch()
            guard !Task.isCancelled else { return }
            methods = saved
            errorMessage = nil
        } catch { errorMessage = "Couldn't load payment preferences. Please retry." }
    }
    func save(_ draft: PaymentMethodDraft) async throws -> PaymentMethod {
        guard !isBusy else { throw PaymentPreferenceError.busy }
        let method = try draft.value()
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await service.save(method)
            methods.removeAll { $0.id == saved.id }
            methods.insert(saved, at: 0)
            errorMessage = nil
            return saved
        } catch {
            errorMessage = "Couldn't save this payment preference. Please retry."
            throw PaymentPreferenceError.unavailable
        }
    }
    func resolve(selectedID: UUID?, draft: PaymentMethodDraft) async throws -> PaymentMethod {
        if let selectedID {
            guard let saved = methods.first(where: { $0.id == selectedID }) else {
                throw PaymentPreferenceError.unavailable
            }
            // Expired saved cards need editing before they can be selected again.
            _ = try PaymentMethodDraft(method: saved).value()
            return saved
        }
        return try await save(draft)
    }
    func delete(_ method: PaymentMethod) async {
        guard !isBusy else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.delete(id: method.id)
            methods.removeAll { $0.id == method.id }
            errorMessage = nil
        } catch { errorMessage = "Couldn't remove this payment preference. Please retry." }
    }
}
