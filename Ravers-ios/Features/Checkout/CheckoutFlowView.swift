//
//  CheckoutFlowView.swift
//  Raverse-ios
//
//  The "Order now" flow, presented from the product screen: Address details →
//  Payment preference → Confirmation. Supabase stores the order before the
//  confirmation appears. Payment stays pending until confirmed by a payment backend.
//

import SwiftUI

/// Hosts the checkout navigation stack. `onFinish` closes the whole flow.
struct CheckoutFlowView: View {
    let items: [VaultItem]
    let fromVault: Bool
    let onFinish: () -> Void
    let onOrderCompleted: () -> Void

    init(product: Product, size: String?, quantity: Int,
         onFinish: @escaping () -> Void, onOrderCompleted: @escaping () -> Void) {
        self.init(items: [VaultItem(id: VaultItem.key(productID: product.id, size: size),
                                   product: product, size: size, quantity: quantity)],
                  fromVault: false, onFinish: onFinish, onOrderCompleted: onOrderCompleted)
    }

    init(items: [VaultItem], fromVault: Bool,
         onFinish: @escaping () -> Void, onOrderCompleted: @escaping () -> Void) {
        self.items = items
        self.fromVault = fromVault
        self.onFinish = onFinish
        self.onOrderCompleted = onOrderCompleted
    }

    var body: some View {
        NavigationStack {
            AddressView(items: items, fromVault: fromVault,
                        onFinish: onFinish, onOrderCompleted: onOrderCompleted)
        }
    }
}

// MARK: - Address details

private struct AddressView: View {
    let items: [VaultItem]
    let fromVault: Bool
    let onFinish: () -> Void
    let onOrderCompleted: () -> Void

    @State private var name = ""
    @State private var phone = ""
    @State private var line = ""
    @State private var city = ""
    @State private var pincode = ""
    @State private var goToPayment = false

    private var address: ShippingAddress {
        ShippingAddress(name: name, phone: phone, line: line, city: city, pincode: pincode)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        phone.filter(\.isNumber).count >= 10 &&
        !line.trimmingCharacters(in: .whitespaces).isEmpty &&
        !city.trimmingCharacters(in: .whitespaces).isEmpty &&
        pincode.filter(\.isNumber).count >= 5
    }

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    CheckoutHeader(title: "DELIVERY ADDRESS", step: 1, onClose: onFinish)

                    CheckoutItemsSummary(items: items)

                    VStack(spacing: 14) {
                        field("Full name", text: $name, placeholder: "Rehan Malhotra")
                        field("Phone", text: $phone, placeholder: "98765 43210", keyboard: .phonePad)
                        field("Address", text: $line, placeholder: "Flat / house, street, area")
                        HStack(spacing: 12) {
                            field("City", text: $city, placeholder: "Bengaluru")
                            field("Pincode", text: $pincode, placeholder: "560102", keyboard: .numberPad)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 440)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            CheckoutBottomButton(title: "CONTINUE TO PAYMENT", enabled: isValid) {
                goToPayment = true
            }
        }
        .navigationDestination(isPresented: $goToPayment) {
            PaymentView(items: items, fromVault: fromVault,
                        address: address,
                        onFinish: onFinish,
                        onOrderCompleted: onOrderCompleted)
        }
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
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.rvBorder, lineWidth: 1)
                )
        }
    }
}

// MARK: - Payment

private struct PaymentView: View {
    let items: [VaultItem]
    let fromVault: Bool
    let address: ShippingAddress
    let onFinish: () -> Void
    let onOrderCompleted: () -> Void

    @Environment(VaultStore.self) private var vault

    @Environment(PaymentMethodStore.self) private var payments
    @State private var selectedMethodID: UUID?
    @State private var paymentDraft = PaymentMethodDraft()
    @State private var placedOrder: Order?
    @State private var requestID = UUID()
    @State private var isPlacingOrder = false
    @State private var errorMessage: String?

    private var total: Int { items.reduce(0) { $0 + $1.total } }

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    CheckoutHeader(title: "PAYMENT", step: 2, onClose: onFinish)

                    CheckoutItemsSummary(items: items)

                    deliveringTo

                    CheckoutPaymentChoice(selectedID: $selectedMethodID, draft: $paymentDraft)

                    Text("Your order will be saved with payment pending. No payment is collected on this screen.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.rvTextMuted)

                    totalRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 440)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            CheckoutBottomButton(title: isPlacingOrder ? "SAVING ORDER…" : "PLACE ORDER · " + priceString(total),
                                 enabled: !items.isEmpty && !isPlacingOrder && !vault.isBusy && !payments.isBusy && paymentIsValid) {
                Task { await placeOrder() }
            }
        }
        .disabled(isPlacingOrder)
        .interactiveDismissDisabled(isPlacingOrder)
        .navigationBarBackButtonHidden(isPlacingOrder)
        .alert("Couldn't place order", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) { } } message: { Text(errorMessage ?? "") }
        .navigationDestination(item: $placedOrder) { order in
            OrderConfirmedView(order: order) {
                onOrderCompleted()
                onFinish()
            }
        }
    }

    private var deliveringTo: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.rvRed)
            VStack(alignment: .leading, spacing: 2) {
                Text(address.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.rvText)
                Text(address.oneLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.rvBorder, lineWidth: 1)
        )
    }

    private var paymentIsValid: Bool {
        if let selectedMethodID, let method = payments.methods.first(where: { $0.id == selectedMethodID }) {
            return (try? PaymentMethodDraft(method: method).value()) != nil
        }
        return selectedMethodID == nil && (try? paymentDraft.value()) != nil
    }

    private var totalRow: some View {
        HStack {
            Text("TOTAL")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
            Spacer()
            Text(priceString(total))
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
        }
        .padding(.top, 4)
    }

    private func placeOrder() async {
        guard !isPlacingOrder else { return }
        isPlacingOrder = true
        defer { isPlacingOrder = false }
        do {
            let method = try await payments.resolve(selectedID: selectedMethodID, draft: paymentDraft)
            selectedMethodID = method.id
            placedOrder = try await vault.placeOrder(id: requestID, items: items, address: address,
                                                     paymentMethod: method.kind.rawValue,
                                                     fromVault: fromVault, paymentMethodID: method.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func priceString(_ value: Int) -> String {
        "₹" + value.formatted(.number.grouping(.automatic))
    }
}

// MARK: - Confirmation

private struct OrderConfirmedView: View {
    let order: Order
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(Color.rvRed)

                Text("ORDER PLACED")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(Color.rvText)

                Text("Your order has been saved. Payment is pending. View your items and delivery details under Vault → Orders.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text("Order reference: \(order.id)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.rvTextMuted)
                    .textSelection(.enabled)
                    .padding(.horizontal, 24)

                VStack(spacing: 6) {
                    Text("ORDER TOTAL " + priceString(order.total))
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.rvText)
                    Text(order.paymentLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.rvTextMuted)
                }
                .padding(.top, 4)

                Spacer()

                Button(action: onFinish) {
                    Text("DONE")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.rvRed, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: 440)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private func priceString(_ value: Int) -> String {
        "₹" + value.formatted(.number.grouping(.automatic))
    }
}

// MARK: - Shared checkout pieces

struct CheckoutHeader: View {
    let title: String
    let step: Int
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.rvText)
                    .frame(width: 40, height: 40)
                    .background(Color.rvSurface, in: Circle())
                    .overlay(Circle().stroke(Color.rvBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .tracking(1)
                .foregroundStyle(Color.rvText)

            Spacer()

            Text("\(step)/2")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.rvTextMuted)
                .frame(width: 40, height: 40)
        }
    }
}

private struct CheckoutItemsSummary: View {
    let items: [VaultItem]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(items) { item in
                CheckoutSummaryStrip(product: item.product, size: item.size, quantity: item.quantity)
            }
        }
    }
}

private struct CheckoutSummaryStrip: View {
    let product: Product
    let size: String?
    let quantity: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(product.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 66)
                .padding(4)
                .background(
                    LinearGradient(colors: [Color.rvRedDeep.opacity(0.4), .black], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.rvText)
                    .lineLimit(1)
                Text([size.map { "Size \($0)" }, "Qty \(quantity)"].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
                Text("₹" + product.price.formatted(.number.grouping(.automatic)))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.rvBorder, lineWidth: 1)
        )
    }
}

struct CheckoutBottomButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(enabled ? Color.rvRed : Color.rvRed.opacity(0.4),
                           in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    CheckoutFlowView(
        product: Product(id: "p", name: "BASSLINE TECH HOODIE", category: "HOODIES",
                         price: 3499, compareAtPrice: 4000, isPartnerKey: false,
                         imageName: "hoody", description: nil, sizes: ["S", "M", "L"]),
        size: "M",
        quantity: 1,
        onFinish: {},
        onOrderCompleted: {}
    )
    .environment(VaultStore())
    .environment(PaymentMethodStore())
}
