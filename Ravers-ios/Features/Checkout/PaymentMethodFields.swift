import SwiftUI

struct PaymentMethodFields: View {
    @Binding var draft: PaymentMethodDraft
    var editing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Payment type", selection: $draft.kind) {
                ForEach(PaymentMethod.Kind.allCases) { kind in Text(kind.title).tag(kind) }
            }
            .pickerStyle(.segmented).disabled(editing)
            if draft.kind == .upi {
                field("UPI ID", text: $draft.upiID, placeholder: "name@bank", keyboard: .emailAddress)
                Text("Enter your UPI ID. Never enter a UPI PIN.").font(.footnote).foregroundStyle(Color.rvTextMuted)
            } else {
                field("Name on card", text: $draft.cardholderName, placeholder: "Name")
                HStack {
                    Text("Card network").foregroundStyle(Color.rvTextMuted)
                    Spacer()
                    Picker("Card network", selection: $draft.cardBrand) {
                        ForEach(PaymentMethodDraft.brands, id: \.self) { Text($0).tag($0) }
                    }.tint(.rvRed)
                }
                field("Last four digits", text: $draft.cardLastFour, placeholder: "1234", keyboard: .numberPad)
                HStack(spacing: 12) {
                    field("Expiry month", text: $draft.expiryMonth, placeholder: "MM", keyboard: .numberPad)
                    field("Expiry year", text: $draft.expiryYear, placeholder: "YYYY", keyboard: .numberPad)
                }
                Text("This saves a card preference only. Full card details will be entered securely when payments are available.")
                    .font(.footnote).foregroundStyle(Color.rvTextMuted)
            }
        }
    }
    private func field(_ title: String, text: Binding<String>, placeholder: String,
                       keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.rvTextMuted)
            TextField(title, text: text, prompt: Text(placeholder).foregroundStyle(Color.rvTextMuted.opacity(0.6)))
                .labelsHidden().accessibilityLabel(title).keyboardType(keyboard)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .privacySensitive().foregroundStyle(Color.rvText)
                .padding(14).background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rvBorder))
        }
    }
}

struct CheckoutPaymentChoice: View {
    @Environment(PaymentMethodStore.self) private var store
    @Binding var selectedID: UUID?
    @Binding var draft: PaymentMethodDraft
    @State private var editingMethod: PaymentMethod?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PAYMENT PREFERENCE").font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.rvText)
            ForEach(store.methods) { method in
                Button { selectedID = method.id } label: {
                    HStack(spacing: 12) {
                        Image(systemName: method.kind.icon).foregroundStyle(Color.rvRed)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(method.label).font(.subheadline.bold())
                            Text(method.detail).font(.caption).foregroundStyle(Color.rvTextMuted)
                        }
                        Spacer()
                        Image(systemName: selectedID == method.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedID == method.id ? Color.rvRed : Color.rvTextMuted)
                    }
                    .foregroundStyle(Color.rvText).padding(14)
                    .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain).privacySensitive()
                HStack {
                    if (try? PaymentMethodDraft(method: method).value()) == nil {
                        Text("Update this preference before checkout.")
                            .font(.caption).foregroundStyle(Color.rvRed)
                    }
                    Spacer()
                    Button("Edit") { editingMethod = method }.font(.caption.bold()).foregroundStyle(Color.rvRed)
                        .accessibilityLabel("Edit \(method.kind.title) preference")
                }
            }
            if !store.methods.isEmpty {
                Button(selectedID == nil ? "Entering a new preference" : "Use a new UPI ID or card preference") { selectedID = nil }
                    .font(.subheadline.bold()).foregroundStyle(Color.rvRed)
            }
            if selectedID == nil {
                PaymentMethodFields(draft: $draft)
                Text("Saved to your account for your next checkout. You can edit or remove it in Accounts & Settings.")
                    .font(.footnote).foregroundStyle(Color.rvTextMuted)
            }
            if store.isLoading { ProgressView().tint(.rvRed) }
            if let error = store.errorMessage {
                Text(error).font(.footnote).foregroundStyle(Color.rvTextMuted)
                Button("Retry saved preferences") { Task { await store.load() } }.foregroundStyle(Color.rvRed)
            }
        }
        .disabled(store.isBusy)
        .task { await store.load() }
        .sheet(item: $editingMethod) { PaymentPreferenceEditor(method: $0) }
    }
}

struct PaymentPreferenceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PaymentMethodStore.self) private var store
    let method: PaymentMethod?
    @State private var draft: PaymentMethodDraft
    @State private var errorMessage: String?
    @State private var isSaving = false
    init(method: PaymentMethod? = nil) {
        self.method = method
        _draft = State(initialValue: PaymentMethodDraft(method: method))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PaymentMethodFields(draft: $draft, editing: method != nil)
                    if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(Color.rvRed) }
                    Button {
                        Task {
                            isSaving = true
                            defer { isSaving = false }
                            do { _ = try await store.save(draft); dismiss() }
                            catch { errorMessage = error.localizedDescription }
                        }
                    } label: {
                        Text(isSaving ? "SAVING…" : "SAVE PREFERENCE").font(.headline)
                            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(16)
                            .background(Color.rvRed, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isSaving || store.isBusy || (try? draft.value()) == nil)
                }
                .padding(20).frame(maxWidth: 440)
            }
            .background(Color.rvBackground).disabled(isSaving)
            .navigationTitle(method == nil ? "Add preference" : "Edit preference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) } }
        }
        .tint(.rvRed).interactiveDismissDisabled(isSaving)
    }
}
