//
//  WishlistView.swift
//  Raverse-ios
//
//  Wishlist (saved items). Pushed from the heart button in the Home header.
//  Shows every product the raver has hearted; tap through to the detail screen
//  or remove from the list. Empty state when nothing is saved yet.
//

import SwiftUI

struct WishlistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WishlistStore.self) private var wishlist

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rvBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    if wishlist.products.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                                spacing: 14
                            ) {
                                ForEach(wishlist.products) { product in
                                    NavigationLink(value: product) {
                                        WishlistCard(product: product) {
                                            wishlist.remove(product)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 28)
                        }
                    }
                }
                .frame(maxWidth: 440)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(
                    product: product,
                    related: wishlist.products.filter { $0.id != product.id }
                )
            }
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

            Text("WISHLIST")
                .font(.system(size: 16, weight: .heavy))
                .tracking(1)
                .foregroundStyle(Color.rvText)

            Spacer()

            // Saved-count badge, balances the back button.
            Text("\(wishlist.count)")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.rvRed)
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "heart")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Color.rvTextMuted)
            Text("Nothing saved yet")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Color.rvText)
            Text("Tap the heart on any drop to keep it here for later.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.rvTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - Wishlist card

private struct WishlistCard: View {
    let product: Product
    /// Tapped the heart — remove from the wishlist.
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Color.rvSurface, Color.black], startPoint: .top, endPoint: .bottom))
                    .frame(height: 210)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )

                Image(product.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(16)

                Button(action: onRemove) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.rvRed)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(8)
            }

            Text(product.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.rvText)
                .lineLimit(1)

            Text("₹\(product.price)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    WishlistView()
        .environment(WishlistStore())
}
