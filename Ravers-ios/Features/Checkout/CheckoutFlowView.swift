//
//  CheckoutFlowView.swift
//  Raverse-ios
//
//  The "Order now" flow, presented from the product screen: Address details →
//  Payment → Confirmation. On payment the order is written into the shared
//  VaultStore so it appears under the Vault's ORDERS tab.
//

import SwiftUI

/// Hosts the checkout navigation stack. `onFinish` closes the whole flow.
struct CheckoutFlowView: View {
    let product: Product
    let size: String?
    let quantity: Int
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            AddressView(product: product, size: size, quantity: quantity, onFinish: onFinish)
        }
    }
}

// MARK: - Address details

private struct AddressView: View {
    let product: Product
    let size: String?
    let quantity: Int
    let onFinish: () -> Void

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

                    CheckoutSummaryStrip(product: product, size: size, quantity: quantity)

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
            PaymentView(product: product, size: size, quantity: quantity,
                        address: address, onFinish: onFinish)
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
    let product: Product
    let size: String?
    let quantity: Int
    let address: ShippingAddress
    let onFinish: () -> Void

    @Environment(VaultStore.self) private var vault

    enum Method: String, CaseIterable { case upi = "UPI", card = "Card" }
    @State private var method: Method = .upi
    @State private var upiID = ""
    @State private var cardNumber = ""
    @State private var cardName = ""
    @State private var expiry = ""
    @State private var placedOrder: Order?

    private var total: Int { product.price * quantity }

    private var isValid: Bool {
        switch method {
        case .upi:
            return upiID.contains("@") && upiID.count > 3
        case .card:
            return cardNumber.filter(\.isNumber).count >= 12 &&
                   !cardName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        ZStack {
            Color.rvBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    CheckoutHeader(title: "PAYMENT", step: 2, onClose: onFinish)

                    CheckoutSummaryStrip(product: product, size: size, quantity: quantity)

                    deliveringTo

                    methodPicker

                    VStack(spacing: 14) {
                        if method == .upi {
                            field("UPI ID", text: $upiID, placeholder: "name@bank", keyboard: .emailAddress)
                        } else {
                            field("Card number", text: $cardNumber, placeholder: "1234 5678 9012 3456", keyboard: .numberPad)
                            field("Name on card", text: $cardName, placeholder: "REHAN MALHOTRA")
                            field("Expiry (MM/YY)", text: $expiry, placeholder: "08/28", keyboard: .numbersAndPunctuation)
                        }
                    }

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
            CheckoutBottomButton(title: "PAY " + priceString(total), enabled: isValid) {
                placeOrder()
            }
        }
        .navigationDestination(item: $placedOrder) { order in
            OrderConfirmedView(order: order, onFinish: onFinish)
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

    private var methodPicker: some View {
        HStack(spacing: 0) {
            ForEach(Method.allCases, id: \.self) { value in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { method = value }
                } label: {
                    Text(value.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(method == value ? .white : Color.rvTextMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(method == value ? AnyShapeStyle(Color.rvRed) : AnyShapeStyle(Color.clear),
                                   in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.rvSurface, in: Capsule())
        .overlay(Capsule().stroke(Color.rvBorder, lineWidth: 1))
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
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.rvBorder, lineWidth: 1)
                )
        }
    }

    private var paymentLabel: String {
        switch method {
        case .upi:  return "UPI · \(upiID)"
        case .card: return "Card •••• " + String(cardNumber.filter(\.isNumber).suffix(4))
        }
    }

    private func placeOrder() {
        guard isValid else { return }
        let order = Order(
            id: UUID().uuidString,
            product: product,
            size: size,
            quantity: quantity,
            total: total,
            address: address,
            paymentLabel: paymentLabel,
            placedAt: .now,
            status: "Placed"
        )
        vault.placeOrder(order)
        placedOrder = order
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

                Text("\(order.product.name) is on its way to \(order.address.name.components(separatedBy: " ").first ?? order.address.name). Track it under Vault → Orders.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                VStack(spacing: 6) {
                    Text("PAID " + priceString(order.total))
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

private struct CheckoutHeader: View {
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

private struct CheckoutBottomButton: View {
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
        onFinish: {}
    )
    .environment(VaultStore())
}
