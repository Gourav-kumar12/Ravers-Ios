
import SwiftUI

struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    /// Saved payment methods. Seeded with a couple of samples until a
    /// wallet backend is wired in; the Add account sheet appends here.
    @State private var methods: [PaymentMethod] = [
        PaymentMethod(kind: .upi, label: "rehan@okhdfc", detail: "UPI"),
        PaymentMethod(kind: .card, label: "•••• 4291", detail: "Visa · Debit")
    ]
    @State private var showAddAccount = false

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    topBar
                    paymentSection
                    preferencesSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 440)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddAccount) {
            AddAccountView { method in
                methods.append(method)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.rvText)
                    .frame(width: 40, height: 40)
                    .background(Color.rvSurface, in: Circle())
                    .overlay(Circle().stroke(Color.rvBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Accounts & Settings")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Color.rvText)

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
    }

    // MARK: - Payment methods

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("PAYMENT METHODS")
                Spacer()
                Button {
                    showAddAccount = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add account")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.rvRed)
                }
                .buttonStyle(.plain)
            }

            if methods.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(methods.enumerated()), id: \.element.id) { index, method in
                        methodRow(method)
                        if index < methods.count - 1 {
                            Divider().overlay(Color.rvBorder).padding(.leading, 56)
                        }
                    }
                }
                .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "creditcard")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Color.rvTextMuted)
            Text("No payment methods yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.rvText)
            Text("Add a UPI ID or a debit / credit card to check out in a tap.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.rvTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func methodRow(_ method: PaymentMethod) -> some View {
        HStack(spacing: 14) {
            Image(systemName: method.kind.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.rvRed)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(method.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.rvText)
                Text(method.detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
            }

            Spacer()

            Button {
                methods.removeAll { $0.id == method.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Account preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("ACCOUNT")
            VStack(spacing: 0) {
                linkRow(icon: "person.text.rectangle", title: "Personal details")
                Divider().overlay(Color.rvBorder).padding(.leading, 56)
                linkRow(icon: "arrow.down.circle", title: "Download my data")
                Divider().overlay(Color.rvBorder).padding(.leading, 56)
                linkRow(icon: "trash", title: "Delete account", destructive: true)
            }
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func linkRow(icon: String, title: String, destructive: Bool = false) -> some View {
        Button {
            // Row action.
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(destructive ? Color.rvRed : Color.rvText)
                    .frame(width: 26)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(destructive ? Color.rvRed : Color.rvText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.rvTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(Color.rvTextMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Payment method model

/// A saved way to pay — either a UPI ID or a debit / credit card.
struct PaymentMethod: Identifiable, Hashable {
    let id = UUID()
    let kind: Kind
    let label: String   // "rehan@okhdfc" or "•••• 4291"
    let detail: String  // "UPI" or "Visa · Debit"

    enum Kind: Hashable {
        case upi
        case card

        var icon: String {
            switch self {
            case .upi:  return "indianrupeesign.circle"
            case .card: return "creditcard"
            }
        }
    }
}

// MARK: - Add account sheet

/// A small form to add a new payment method. Toggles between UPI and card
/// entry and hands the finished method back to the caller on Save.
private struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss

    /// Called with the new method when the raver taps Save.
    let onSave: (PaymentMethod) -> Void

    @State private var kind: PaymentMethod.Kind = .upi

    // UPI
    @State private var upiID = ""
    // Card
    @State private var cardNumber = ""
    @State private var cardName = ""
    @State private var expiry = ""

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.rvBorder)
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                Text("Add account")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color.rvText)

                kindPicker

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        if kind == .upi {
                            field("UPI ID", text: $upiID, placeholder: "name@bank", keyboard: .emailAddress)
                        } else {
                            field("Card number", text: $cardNumber, placeholder: "1234 5678 9012 3456", keyboard: .numberPad)
                            field("Name on card", text: $cardName, placeholder: "REHAN MALHOTRA")
                            field("Expiry (MM/YY)", text: $expiry, placeholder: "08/28", keyboard: .numbersAndPunctuation)
                        }
                    }
                    .padding(.top, 4)
                }

                saveButton

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        }
    }

    private var kindPicker: some View {
        HStack(spacing: 0) {
            segment(title: "UPI", value: .upi)
            segment(title: "Card", value: .card)
        }
        .padding(4)
        .background(Color.rvSurface, in: Capsule())
        .overlay(Capsule().stroke(Color.rvBorder, lineWidth: 1))
    }

    private func segment(title: String, value: PaymentMethod.Kind) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { kind = value }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(kind == value ? Color.rvText : Color.rvTextMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    kind == value
                    ? AnyShapeStyle(Color.rvRed)
                    : AnyShapeStyle(Color.clear),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Color.rvTextMuted)
            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Color.rvTextMuted.opacity(0.6)))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.rvText)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(kind == .card && title.hasPrefix("Name") ? .characters : .never)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.rvBorder, lineWidth: 1)
                )
        }
    }

    private var saveButton: some View {
        Button {
            guard let method = buildMethod() else { return }
            onSave(method)
            dismiss()
        } label: {
            Text("Save")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isValid ? Color.rvRed : Color.rvRed.opacity(0.4),
                           in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isValid)
    }

    // MARK: - Validation & assembly

    private var isValid: Bool {
        switch kind {
        case .upi:
            return upiID.contains("@") && upiID.count > 3
        case .card:
            let digits = cardNumber.filter(\.isNumber)
            return digits.count >= 12 && !cardName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func buildMethod() -> PaymentMethod? {
        guard isValid else { return nil }
        switch kind {
        case .upi:
            return PaymentMethod(kind: .upi, label: upiID, detail: "UPI")
        case .card:
            let last4 = String(cardNumber.filter(\.isNumber).suffix(4))
            return PaymentMethod(kind: .card, label: "•••• \(last4)", detail: "Debit / Credit")
        }
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView()
    }
}
