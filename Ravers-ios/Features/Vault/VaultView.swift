

import SwiftUI

struct VaultView: View {
    @Environment(VaultStore.self) private var vault
    @State private var selectedTab: VaultTab = .holding
    @State private var checkout: VaultCheckout?
    @State private var errorMessage: String?
    @Binding private var requestedTab: VaultTab?

    init(requestedTab: Binding<VaultTab?> = .constant(nil)) {
        _requestedTab = requestedTab
    }

    init(initialTab: VaultTab) {
        _selectedTab = State(initialValue: initialTab)
        _requestedTab = .constant(nil)
    }

    private struct VaultCheckout: Identifiable {
        let id = UUID()
        let items: [VaultItem]
    }

    enum VaultTab: String, CaseIterable, Identifiable {
        case holding = "HOLDING"
        case passes  = "PASSES"
        case orders  = "ORDERS"
//        case saved   = "SAVED"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    tabBar
                    if vault.isLoading { ProgressView().tint(.rvRed) }
                    if selectedTab == .orders && vault.isShowingSavedOrders {
                        Text("Showing saved orders. Refreshing when connected.")
                            .font(.footnote).foregroundStyle(Color.rvTextMuted)
                    }
                    if selectedTab == .passes && vault.isShowingSavedTickets {
                        Text("Showing saved bookings. Refreshing when connected.")
                            .font(.footnote).foregroundStyle(Color.rvTextMuted)
                    }
                    if let error = vault.loadError {
                        Text(error).font(.subheadline).foregroundStyle(Color.rvTextMuted)
                        Button("Retry loading Vault") { Task { await vault.load() } }
                    }
                    content
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: 440)
        }
        .task { await vault.load() }
        .onChange(of: requestedTab, initial: true) { _, tab in
            if let tab {
                selectedTab = tab
                requestedTab = nil
            }
        }
        .refreshable { await vault.load() }
        .alert("Couldn't update Vault", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) { } } message: { Text(errorMessage ?? "") }
        .fullScreenCover(item: $checkout) { selection in
            CheckoutFlowView(
                items: selection.items,
                fromVault: true,
                onFinish: { checkout = nil },
                onOrderCompleted: { selectedTab = .orders }
            )
        }
    }

    //  - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("VAULT")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Everything you hold with us.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
            }

            Spacer()

            partnerKeyBadge
        }
    }

    private var partnerKeyBadge: some View {
        HStack(spacing: 7) {
            Image(systemName: "key.fill")
                .font(.system(size: 11, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text("PARTNER KEY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                Text(vault.hasPartnerAccess ? "ACTIVE" : "LOCKED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.0)
            }
        }
        .foregroundStyle(Color.rvRed)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.rvRed.opacity(0.6), lineWidth: 1)
        )
    }

    // MARK: - Segmented tabs

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(VaultTab.allCases) { tab in
                let selected = selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(selected ? .white : Color.rvTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selected ? Color.rvRed : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Content per tab

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .holding:
            if vault.items.isEmpty {
                emptyState(icon: "bag", message: "Nothing in your vault yet.")
            } else {
                holdingContent
            }
        case .passes:
            if vault.tickets.isEmpty {
                if vault.isLoading {
                    emptyState(icon: "ticket", message: "Loading your passes…")
                } else if !vault.ticketsAreCurrent {
                    emptyState(icon: "ticket", message: "Couldn't load your passes. Pull down to retry.")
                } else {
                    emptyState(icon: "ticket", message: "No passes yet.")
                }
            } else {
                VStack(spacing: 16) {
                    ForEach(vault.tickets) { TicketCard(ticket: $0) }
                }
            }
        case .orders:
            if vault.orders.isEmpty {
                if vault.isLoading {
                    emptyState(icon: "shippingbox", message: "Loading your orders…")
                } else if !vault.ordersAreCurrent {
                    emptyState(icon: "shippingbox", message: "Couldn't load your orders. Pull down to retry.")
                } else {
                    emptyState(icon: "shippingbox", message: "No orders yet.")
                }
            } else {
                ordersContent
            }
//        case .saved:
//            emptyState(icon: "bookmark", message: "Nothing saved yet.")
        }
    }

    private var ordersContent: some View {
        VStack(spacing: 16) {
            ForEach(vault.orders) { order in
                OrderCard(order: order)
            }
        }
    }

    private var holdingContent: some View {
        VStack(spacing: 16) {
            ForEach(vault.items) { item in
                VaultItemCard(
                    item: item,
                    onIncrement: { updateCart { try await vault.increment(item) } },
                    onDecrement: { updateCart { try await vault.decrement(item) } },
                    onRemove: { updateCart { try await vault.remove(item) } }
                )
            }

            summaryCard
        }
        .disabled(vault.isBusy)
    }

    private func updateCart(_ action: @escaping @MainActor () async throws -> Void) {
        Task {
            do { try await action() }
            catch { errorMessage = error.localizedDescription }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 14) {
            summaryRow(label: "Goods", value: priceString(vault.goodsTotal))
            summaryRow(label: "Shipping", value: "Free")

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            HStack {
                Text("TOTAL")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
                Spacer()
                Text(priceString(vault.goodsTotal))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
            }

            Button {
                checkout = VaultCheckout(items: vault.items)
            } label: {
                Text("CHECKOUT")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.rvRed, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.rvTextMuted)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.rvText)
        }
    }

    // MARK: - Empty state

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.rvTextMuted)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.rvTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func priceString(_ value: Int) -> String {
        "₹" + value.formatted(.number.grouping(.automatic))
    }
}

// MARK: - Cart line item

private struct VaultItemCard: View {
    let item: VaultItem
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(item.product.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 92)
                .padding(6)
                .background(
                    LinearGradient(colors: [Color.rvRedDeep.opacity(0.4), .black], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.product.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.rvText)
                        .lineLimit(1)

                    if let size = item.size {
                        Text("Size \(size)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.rvTextMuted)
                    }

                    Text("₹" + item.product.price.formatted(.number.grouping(.automatic)))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }

                HStack {
                    stepper
                    Spacer()
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.rvTextMuted)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.04), in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }

            Text("\(item.quantity)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(minWidth: 28)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }
        }
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Saved purchase history

private struct OrderCard: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ORDER · " + String(order.id.suffix(8)).uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Spacer()
                Text(order.statusLabel.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color.rvRed)
            }
            ForEach(order.items) { item in
                HStack(spacing: 14) {
                    Image(item.product.imageName)
                        .resizable().scaledToFit().frame(width: 54, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.product.name).font(.system(size: 14, weight: .bold))
                        Text([item.size.map { "Size \($0)" }, "Qty \(item.quantity)"]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 12)).foregroundStyle(Color.rvTextMuted)
                    }
                    Spacer()
                    Text("₹" + item.total.formatted()).font(.system(size: 13, weight: .bold))
                }
            }
            Divider().overlay(Color.rvBorder)
            Text("Total ₹" + order.total.formatted()).font(.system(size: 14, weight: .bold))
            Text("\(order.address.name) · \(order.address.oneLine)")
                .font(.system(size: 12)).foregroundStyle(Color.rvTextMuted)
            Text("\(order.paymentLabel) · \(order.placedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.system(size: 12)).foregroundStyle(Color.rvTextMuted)
        }
        .foregroundStyle(Color.rvText)
        .padding(16)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.rvBorder, lineWidth: 1))
    }
}

private struct TicketCard: View {
    let ticket: Ticket

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(ticket.event.name, systemImage: "ticket.fill")
                .font(.system(size: 17, weight: .bold))
            Text("\(ticket.tier.name) · \(ticket.quantity) entry · ₹\(ticket.total.formatted())")
                .font(.system(size: 13))
            Text(ticket.event.date.formatted(date: .abbreviated, time: .shortened))
            Text("\(ticket.event.venue), \(ticket.event.city)")
            Text(ticket.statusLabel.uppercased())
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color.rvRed)
            if let method = ticket.paymentMethod {
                Text("Payment preference: \(method == "card" ? "Card" : "UPI")")
                    .font(.footnote).foregroundStyle(Color.rvTextMuted)
            }
            Text("Booking reference: \(ticket.id)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.rvTextMuted)
                .textSelection(.enabled)
            if ticket.isActive, let code = ticket.code {
                Text(code).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
            }
            if ticket.grantsEventChat {
                NavigationLink { EventChatView(event: ticket.event) } label: {
                    Label("Open event group", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.subheadline.bold()).foregroundStyle(Color.rvRed)
                }
            } else if ticket.paymentStatus == "pending" {
                Text("Event group opens after payment confirmation.")
                    .font(.footnote).foregroundStyle(Color.rvTextMuted)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Color.rvText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.rvBorder, lineWidth: 1))
    }
}
