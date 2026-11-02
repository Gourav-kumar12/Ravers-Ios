import SwiftUI

/// Tickets use the same payment selection, saved preferences and visual components
/// as product checkout. They do not ask for a delivery address.
struct TicketCheckoutFlowView: View {
    let event: Event
    let tiers: [Pass]
    let onFinish: () -> Void
    let onCompleted: () -> Void
    @Environment(VaultStore.self) private var vault
    @Environment(PaymentMethodStore.self) private var payments
    @State private var selectedTierID: String
    @State private var selectedMethodID: UUID?
    @State private var paymentDraft = PaymentMethodDraft()
    @State private var requestID = UUID()
    @State private var isBooking = false
    @State private var errorMessage: String?
    @State private var ticket: Ticket?

    init(event: Event, tiers: [Pass], onFinish: @escaping () -> Void, onCompleted: @escaping () -> Void) {
        self.event = event; self.tiers = tiers; self.onFinish = onFinish; self.onCompleted = onCompleted
        _selectedTierID = State(initialValue: tiers.first?.id ?? "")
    }
    private var selectedTier: Pass? { tiers.first { $0.id == selectedTierID } }
    private var paymentIsValid: Bool {
        if let selectedMethodID, let method = payments.methods.first(where: { $0.id == selectedMethodID }) {
            return (try? PaymentMethodDraft(method: method).value()) != nil
        }
        return selectedMethodID == nil && (try? paymentDraft.value()) != nil
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    CheckoutHeader(title: "TICKET PAYMENT", step: 2, onClose: onFinish)
                    HStack(spacing: 14) {
                        Image(systemName: "ticket.fill").font(.largeTitle).foregroundStyle(Color.rvRed)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(event.name).font(.title3.bold()).foregroundStyle(Color.rvText)
                            Text(event.venue).font(.subheadline).foregroundStyle(Color.rvTextMuted)
                            Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.footnote).foregroundStyle(Color.rvTextMuted)
                        }
                    }
                    Picker("Ticket tier", selection: $selectedTierID) {
                        ForEach(tiers) { tier in Text("\(tier.name) · ₹\(tier.price.formatted())").tag(tier.id) }
                    }
                    .tint(.rvRed).foregroundStyle(Color.rvText)
                    Text("1 entry").font(.footnote).foregroundStyle(Color.rvTextMuted)
                    CheckoutPaymentChoice(selectedID: $selectedMethodID, draft: $paymentDraft)
                    Text("Your booking will be saved with payment pending. No payment is collected on this screen. Your event group opens after payment confirmation.")
                        .font(.footnote).foregroundStyle(Color.rvTextMuted)
                    HStack {
                        Text("TOTAL"); Spacer(); Text("₹\((selectedTier?.price ?? 0).formatted())")
                    }.font(.headline).foregroundStyle(Color.rvText)
                    if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(Color.rvRed) }
                }
                .padding(20).frame(maxWidth: 440)
            }
            .background(Color.rvBackground).toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                CheckoutBottomButton(title: isBooking ? "SAVING BOOKING…" : "BOOK PASS · ₹\((selectedTier?.price ?? 0).formatted())",
                    enabled: !isBooking && !vault.isBusy && !payments.isBusy && selectedTier != nil && paymentIsValid && event.date > .now) {
                    Task { await book() }
                }
            }
            .disabled(isBooking).interactiveDismissDisabled(isBooking)
            .navigationDestination(item: $ticket) { saved in
                VStack(spacing: 22) {
                    Spacer()
                    Image(systemName: "ticket.fill").font(.system(size: 64)).foregroundStyle(Color.rvRed)
                    Text("BOOKING SAVED").font(.title.bold()).foregroundStyle(Color.rvText)
                    Text("Payment is pending. Your booking and chosen payment preference are saved in your account.")
                        .multilineTextAlignment(.center).foregroundStyle(Color.rvTextMuted)
                    Text("Booking reference: \(saved.id)").font(.caption.monospaced()).textSelection(.enabled)
                        .foregroundStyle(Color.rvTextMuted)
                    if let method = saved.paymentMethod {
                        Label(method == "card" ? "Card preference saved" : "UPI preference saved",
                              systemImage: method == "card" ? "creditcard" : "indianrupeesign.circle")
                            .font(.subheadline).foregroundStyle(Color.rvText)
                    }
                    Spacer()
                    CheckoutBottomButton(title: "VIEW MY PASS", enabled: true, action: onCompleted)
                }
                .padding(20).frame(maxWidth: .infinity).background(Color.rvBackground)
                .toolbar(.hidden, for: .navigationBar).navigationBarBackButtonHidden()
            }
        }
    }
    private func book() async {
        guard !isBooking, let tier = selectedTier, event.date > .now else { return }
        isBooking = true
        errorMessage = nil
        defer { isBooking = false }
        do {
            let method = try await payments.resolve(selectedID: selectedMethodID, draft: paymentDraft)
            selectedMethodID = method.id
            ticket = try await vault.bookTicket(id: requestID, event: event, tier: tier, paymentMethodID: method.id)
        } catch { errorMessage = error.localizedDescription }
    }
}
