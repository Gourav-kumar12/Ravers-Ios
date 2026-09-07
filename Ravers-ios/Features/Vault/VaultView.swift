

import SwiftUI

struct VaultView: View {
    @Environment(VaultStore.self) private var vault
    @State private var selectedTab: VaultTab = .holding

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
                    content
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: 440)
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
                Text("ACTIVE")
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
            emptyState(icon: "ticket", message: "No passes yet.")
        case .orders:
            if vault.orders.isEmpty {
                emptyState(icon: "shippingbox", message: "No orders yet.")
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
                    onIncrement: { vault.increment(item) },
                    onDecrement: { vault.decrement(item) },
                    onRemove: { withAnimation(.easeInOut(duration: 0.2)) { vault.remove(item) } }
                )
            }

            summaryCard
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
                // Checkout action.
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

// MARK: - Order card

private struct OrderCard: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(order.product.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 78)
                    .padding(5)
                    .background(
                        LinearGradient(colors: [Color.rvRedDeep.opacity(0.4), .black], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(order.product.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.rvText)
                        .lineLimit(1)

                    Text([order.size.map { "Size \($0)" }, "Qty \(order.quantity)"].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.rvTextMuted)

                    Text("₹" + order.total.formatted(.number.grouping(.automatic)))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(order.status.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color.rvRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.rvRed.opacity(0.15), in: Capsule())
            }

            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                detailRow(icon: "location.fill", text: "\(order.address.name) · \(order.address.oneLine)")
                detailRow(icon: "creditcard.fill", text: order.paymentLabel)
                detailRow(icon: "calendar", text: order.placedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding(16)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.rvTextMuted)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.rvTextMuted)
                .lineLimit(1)
        }
    }
}

#Preview {
    let store = VaultStore()
    store.add(
        Product(id: "catalog-c", name: "BASSLINE TECH HOODIE", category: "HOODIES", price: 3499, compareAtPrice: 4000, isPartnerKey: true, imageName: "hoody", description: nil, sizes: ["S", "M", "L", "XL"]),
        size: "M"
    )
    return VaultView()
        .environment(store)
}
