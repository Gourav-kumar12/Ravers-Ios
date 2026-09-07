//
//  ProductDetailView.swift
//  Raverse-ios
//

//

import SwiftUI

struct ProductDetailView: View {
    let product: Product
    /// Other catalog items shown in the "RUNS WITH IT" carousel.
    var related: [Product] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var vault
    @Environment(WishlistStore.self) private var wishlist
    @State private var selectedSize: String?
    @State private var showVaultToast = false
    @State private var goToVault = false
    @State private var showCheckout = false

    private var sizes: [String] { product.sizes ?? [] }
    private var specs: [String] { product.specs ?? [] }

    var body: some View {
        ZStack(alignment: .top) {
            Color.rvBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    heroImage

                    VStack(alignment: .leading, spacing: 22) {
                        tagRow
                        titleBlock
                        if !sizes.isEmpty { sizeSection }
                        if !specs.isEmpty { specSection }
                        if !related.isEmpty { runsWithItSection }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 440)
            .ignoresSafeArea(edges: .top)

            header
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .overlay(alignment: .top) {
            if showVaultToast {
                vaultToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Product.self) { next in
            ProductDetailView(product: next, related: related.filter { $0.id != next.id })
        }
        .navigationDestination(isPresented: $goToVault) {
            VaultView()
        }
        .fullScreenCover(isPresented: $showCheckout) {
            CheckoutFlowView(product: product, size: selectedSize, quantity: 1) {
                showCheckout = false
            }
        }
    }

    // MARK: - Add-to-vault toast

    private var vaultToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("ADDED TO VAULT")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                Text(product.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(colors: [.rvRed, .rvRedDeep], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.rvRed.opacity(0.45), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 16)
    }

    private func addToVault() {
        vault.add(product, size: selectedSize)

        // Flash the confirmation toast, then slide into the Vault.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showVaultToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            showVaultToast = false
            goToVault = true
        }
    }

    // MARK: - Header (back + save)

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.06), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }

            Spacer()

            Button {
                wishlist.toggle(product)
            } label: {
                Image(systemName: wishlist.contains(product) ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(wishlist.contains(product) ? Color.rvRed : .white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.06), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    // MARK: - Hero image

    private var heroImage: some View {
        Image(product.imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 550)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.10, green: 0.02, blue: 0.03), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipped()
            .overlay(alignment: .bottom) {
                // Fade the image into the page background.
                LinearGradient(
                    colors: [.clear, Color.rvBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
            }
    }

    // MARK: - Tags

    private var tagRow: some View {
        HStack(spacing: 10) {
            Text(product.category)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.rvTextMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))

            if product.isPartnerKey {
                HStack(spacing: 5) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("PARTNER KEY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                }
                .foregroundStyle(Color.rvRed)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(Capsule().stroke(Color.rvRed.opacity(0.6), lineWidth: 1))
            }
        }
    }

    // MARK: - Title / price / description

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(product.name)
                .font(.system(size: 30, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(.white)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(priceString(product.price))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.rvRed)

                if let compare = product.compareAtPrice {
                    Text(priceString(compare))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.rvTextMuted)
                        .strikethrough(true, color: Color.rvTextMuted)
                }
            }

            if let description = product.description {
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.rvTextMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Size selector

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("SIZE")

            HStack(spacing: 12) {
                ForEach(sizes, id: \.self) { size in
                    let selected = selectedSize == size
                    Button {
                        selectedSize = size
                    } label: {
                        Text(size)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(selected ? .black : .white)
                            .frame(width: 48, height: 44)
                            .background(selected ? Color.rvRed : Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selected ? Color.rvRed : Color.white.opacity(0.22), lineWidth: 1.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Spec chips

    private var specSection: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(specs, id: \.self) { spec in
                Text(spec)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.rvText.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Runs with it

    private var runsWithItSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("RUNS WITH IT")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(related) { item in
                        NavigationLink(value: item) {
                            RelatedProductCard(product: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Sticky bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Secondary: drop into the cart.
            Button {
                addToVault()
            } label: {
                Text("addToVault")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.rvRed, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            // Primary: buy now → address → payment.
            Button {
                showCheckout = true
            } label: {
                Text("ORDER NOW")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.rvRed, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .tracking(1.4)
            .foregroundStyle(.white)
    }

    private func priceString(_ value: Int) -> String {
        "₹" + value.formatted(.number.grouping(.automatic))
    }
}

// MARK: - Related product card

private struct RelatedProductCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [Color.rvRedDeep.opacity(0.55), .black], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                Image(product.imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(14)

                if product.isPartnerKey {
                    PartnerKeyTag()
                        .scaleEffect(0.85, anchor: .topLeading)
                        .padding(8)
                }
            }
            .frame(width: 150, height: 170)

            Text(product.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.rvText)
                .lineLimit(1)

            Text("₹" + product.price.formatted(.number.grouping(.automatic)))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 150)
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(
            product: Product(
                id: "preview",
                name: "BASSLINE TECH HOODIE",
                category: "APPAREL",
                price: 3499,
                compareAtPrice: 4000,
                isPartnerKey: true,
                imageName: "hoody",
                description: "Matte technical shell with crimson zip pulls. Built for basements that run cold until the floor fills.",
                sizes: ["S", "M", "L", "XL"],
                specs: ["820 GSM brushed fleece", "Crimson zip hardware", "Hidden chest pocket", "Left-chest wordmark"]
            ),
            related: [
                Product(id: "r1", name: "Signal Chain", category: "ACCESSORIES", price: 7199, compareAtPrice: nil, isPartnerKey: true, imageName: "chain", description: nil),
                Product(id: "r2", name: "RAVERSIN Tee", category: "T-SHIRTS", price: 2499, compareAtPrice: nil, isPartnerKey: true, imageName: "t-shirt", description: nil)
            ]
        )
    }
    .environment(VaultStore())
    .environment(WishlistStore())
}
