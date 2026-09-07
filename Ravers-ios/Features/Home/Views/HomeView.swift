
//  HomeView.swift



import SwiftUI

struct HomeView: View {
    @State private var model = HomeViewModel()
    @Environment(WishlistStore.self) private var wishlist
    @State private var showWishlist = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rvBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView
                        .padding(.horizontal, 18)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            if let hero = model.heroProduct {
                                NavigationLink(value: hero) {
                                    HeroProductCard(product: hero)
                                }
                                .buttonStyle(.plain)
                            }

                            categorySection

                            sectionHeader

                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                                ForEach(model.filteredCatalog) { product in
                                    NavigationLink(value: product) {
                                        CatalogCard(product: product)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 28)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .frame(maxWidth: 420)
            }
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(
                    product: product,
                    related: model.catalog.filter { $0.id != product.id }
                )
            }
        }
        .fullScreenCover(isPresented: $showWishlist) {
            WishlistView()
        }
        .task { await model.load() }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(model.categories) { category in
                        CategoryButton(
                            title: category.title,
                            icon: category.icon,
                            isSelected: model.selectedCategory == category.id,
                            action: {
                                model.selectedCategory = category.id
                            }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
    
    private var sectionHeader: some View {
        HStack(alignment: .center) {
            Text("CATEGORY")
                .font(.system(size: 15, weight: .heavy, design: .default))
                .tracking(1.4)
                .foregroundStyle(.white)
            
            Spacer()
            
            Text(model.selectedCategory == "ALL" ? "ALL ITEMS" : model.selectedCategory)
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundStyle(Color.rvText.opacity(0.75))
                .tracking(1.2)
        }
        .padding(.horizontal, 2)
    }
    
    private var headerView: some View {
        HStack(alignment: .center) {
            HStack() {
                ZStack {
                    Image("logo")
                        .resizable()
                        .frame(width: 100, height: 100)
                    
                }
        
                
            }
            
            Spacer()
            
            HStack(spacing: 14) {
                Button {
                    showWishlist = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: wishlist.count > 0 ? "heart.fill" : "heart")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(wishlist.count > 0 ? Color.rvRed : .white)

                        if wishlist.count > 0 {
                            Text("\(wishlist.count)")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.rvRed, in: Circle())
                                .overlay(Circle().stroke(Color.rvBackground, lineWidth: 1.5))
                                .offset(x: 8, y: -6)
                        }
                    }
                }
                .buttonStyle(.plain)

                Image(systemName: "bag")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct CategoryButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .padding(12)
                .background(
                    isSelected ? Color.rvRed : Color.black
                )
//                .animation(.bouncy)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(isSelected ? Color.rvRed : Color.white.opacity(0.5), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .accessibilityLabel(title)
    }
}

private struct SectionLabel: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .default))
            .tracking(1.2)
            .foregroundStyle(Color.rvText.opacity(0.9))
            .padding(.horizontal, 4)
            .padding(.top, 6)
    }
}

//Hero product section

struct HeroProductCard: View {
    
    let product: Product
    
    var body: some View {
        
        ZStack {
            
            //  Animated Background
            
            AnimatedGradientBackground()
            
            VStack(spacing: 0) {
                
                // Hero Section
                
                ZStack {
                    
                    VStack(spacing: 14) {
                        
                        // MARK: - Product Image
                        
                        ZStack {
                            
                            // Red glow behind image
                            RoundedRectangle(
                                cornerRadius: 28,
                                style: .continuous
                            )
                            .fill(
                                Color.rvRed.opacity(0.12)
                            )
                            .blur(radius: 25)
                            
                            
                            // Product Image
                            Image(product.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(
                                    width: 300,
                                    height: 300
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 28,
                                        style: .continuous
                                    )
                                )
                                .overlay {
                                    
                                    // Premium Gradient Border
                                    RoundedRectangle(
                                        cornerRadius: 28,
                                        style: .continuous
                                    )
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.35),
                                                Color.rvRed.opacity(0.65),
                                                .white.opacity(0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                                }
                                .shadow(
                                    color: Color.rvRed.opacity(0.20),
                                    radius: 18,
                                    x: 0,
                                    y: 8
                                )
                        }
                        .frame(
                            width: 300,
                            height: 300
                        )
                        .padding(.top, 20)
                        
                        
                        // MARK: - Product Name
                        
                        Text(product.name)
                            .font(
                                .system(
                                    size: 26,
                                    weight: .heavy
                                )
                            )
                            .foregroundStyle(.white)
                            .tracking(0.8)
                        
                        
                        // MARK: - Product Description
                        
                        Text(product.description ?? "")
                            .font(
                                .system(
                                    size: 12,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(
                                Color.rvText.opacity(0.7)
                            )
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 250)
                        
                        
                        // MARK: - Shop Now Button
                        
                        Button {
                            
                            // Shop Now action
                            
                        } label: {
                            
                            Text("SHOP NOW")
                                .font(
                                    .system(
                                        size: 14,
                                        weight: .bold
                                    )
                                )
                                .foregroundStyle(.white)
                                .padding(
                                    .horizontal,
                                    26
                                )
                                .padding(
                                    .vertical,
                                    12
                                )
                                .frame(
                                    maxWidth: 180
                                )
                                .background(
                                    Color.rvRed
                                )
                                .clipShape(
                                    Capsule()
                                )
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.vertical, 18)
                }
                .frame(height: 480)
                
                .padding(.horizontal, 20)
                
            }
        }
    }
}

private struct CatalogCard: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Color.rvSurface, Color.black], startPoint: .top, endPoint: .bottom))
                    .frame(height: 250)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                
                Image(product.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(16)

                if product.isPartnerKey {
                    PartnerKeyTag()
                        .padding(8)
                }
            }
            
            Text(product.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.rvText)
            
            HStack(spacing: 8) {
                Text("₹\(product.price)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(VaultStore())
        .environment(WishlistStore())
}
