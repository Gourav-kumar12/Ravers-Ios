
import SwiftUI

struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Environment(PaymentMethodStore.self) private var payments
    @State private var showAddAccount = false
    @State private var editingMethod: PaymentMethod?

    private var methods: [PaymentMethod] { payments.methods }

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
        .task { await payments.load() }
        .refreshable { await payments.load() }
        .sheet(isPresented: $showAddAccount) {
            PaymentPreferenceEditor(method: editingMethod)
                .presentationDetents([.large])
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
                    editingMethod = nil
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

            if payments.isLoading { ProgressView().tint(.rvRed) }
            if let error = payments.errorMessage {
                Text(error).font(.footnote).foregroundStyle(Color.rvTextMuted)
                Button("Retry payment preferences") { Task { await payments.load() } }
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
            Text("Save a UPI ID or masked card preference for checkout.")
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
                editingMethod = method
                showAddAccount = true
            } label: {
                Image(systemName: "pencil").frame(width: 40, height: 40).foregroundStyle(Color.rvRed)
            }
            .accessibilityLabel("Edit payment preference")
            .disabled(payments.isBusy)

            Button {
                Task { await payments.delete(method) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove payment preference")
            .disabled(payments.isBusy)
        }
        .privacySensitive()
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

#Preview {
    NavigationStack { AccountSettingsView() }.environment(PaymentMethodStore())
}
