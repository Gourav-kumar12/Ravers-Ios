//
//  HomeViewModel.swift
//  Raverse-ios
//

import SwiftUI

struct CategoryOption: Identifiable {
    let id: String
    let title: String
    let icon: String
}

@Observable
final class HomeViewModel {
    var heroProduct: Product?
    var newDrops: [Product] = []
    var catalog: [Product] = []
    var selectedCategory: String = "ALL"

    // `icon` is an SF Symbol name representing each category.
    let categories: [CategoryOption] = [
        CategoryOption(id: "ALL", title: "ALL", icon: "square.grid.2x2.fill"),
        CategoryOption(id: "HEADWEAR", title: "HEADWEAR", icon: "hat.cap.fill"),
        CategoryOption(id: "T-SHIRTS", title: "T-SHIRTS", icon: "tshirt.fill"),
        CategoryOption(id: "HOODIES", title: "HOODIES", icon: "hanger"),
        CategoryOption(id: "JACKETS", title: "JACKETS", icon: "coat.fill"),
        CategoryOption(id: "BOTTOMS", title: "BOTTOMS", icon: "shoe.fill"),
        CategoryOption(id: "ACCESSORIES", title: "ACCESSORIES", icon: "eyeglasses")
    ]

    var filteredCatalog: [Product] {
        if selectedCategory == "ALL" {
            return catalog
        }
        return catalog.filter { $0.category == selectedCategory }
    }

    func load() async {
        if heroProduct != nil && !newDrops.isEmpty && !catalog.isEmpty { return }

        let hero = Product(
            id: "ravers-tee",
            name: "RAVERS TEE",
            category: "T-SHIRTS",
            price: 2499,
            compareAtPrice: 2999,
            isPartnerKey: false,
            imageName: "t-shirt",
            description: "Heavyweight cotton, machined seams, gone by sunrise. The flagship drop.",
            sizes: ["S", "M", "L", "XL"],
            specs: ["240 GSM combed cotton", "Machined flatlock seams", "Screen-printed wordmark", "Pre-shrunk boxy fit"]
        )

        let drops = [
            Product(id: "drop-a", name: "RAVERS Zip Hoodie", category: "HOODIES", price: 4499, compareAtPrice: 5499, isPartnerKey: true, imageName: "hoody", description: nil),
            Product(id: "drop-b", name: "Bomber Jacket", category: "JACKETS", price: 5499, compareAtPrice: nil, isPartnerKey: true, imageName: "jacket", description: nil),
            Product(id: "drop-c", name: "Signal Chain", category: "ACCESSORIES", price: 7199, compareAtPrice: nil, isPartnerKey: true, imageName: "chain", description: nil)
        ]

        let catalog = [
            Product(id: "catalog-a", name: "Signal Cap", category: "HEADWEAR", price: 1999, compareAtPrice: nil, isPartnerKey: true, imageName: "cap", description: "Curved-brim cap with a stitched signal mark. One size, hard fit.", specs: ["Structured 6-panel", "Embroidered wordmark", "Adjustable strap back"]),
            Product(id: "catalog-b", name: "RAVERSIN Tee", category: "T-SHIRTS", price: 2499, compareAtPrice: nil, isPartnerKey: false, imageName: "t-shirt", description: "Everyday heavyweight tee cut for the floor.", sizes: ["S", "M", "L", "XL"], specs: ["240 GSM combed cotton", "Ribbed crew neck", "Left-chest wordmark"]),
            Product(id: "catalog-c", name: "BASSLINE TECH HOODIE", category: "HOODIES", price: 3499, compareAtPrice: 4000, isPartnerKey: true, imageName: "hoody", description: "Matte technical shell with crimson zip pulls. Built for basements that run cold until the floor fills.", sizes: ["S", "M", "L", "XL"], specs: ["820 GSM brushed fleece", "Crimson zip hardware", "Hidden chest pocket", "Left-chest wordmark"]),
            Product(id: "catalog-d", name: "Bomber Jacket", category: "JACKETS", price: 5499, compareAtPrice: nil, isPartnerKey: true, imageName: "jacket", description: "Insulated bomber with a matte crimson lining.", sizes: ["S", "M", "L", "XL"], specs: ["Water-repellent shell", "Quilted crimson lining", "Ribbed storm cuffs", "Zip stash pocket"]),
            Product(id: "catalog-e", name: "Cargo Pants", category: "BOTTOMS", price: 3599, compareAtPrice: nil, isPartnerKey: false, imageName: "jeans", description: "Tapered technical cargos with a raver-ready silhouette.", sizes: ["S", "M", "L", "XL"], specs: ["Ripstop cotton blend", "Bellowed side pockets", "Adjustable ankle cuffs"]),
            Product(id: "catalog-f", name: "Signal Chain", category: "ACCESSORIES", price: 7199, compareAtPrice: nil, isPartnerKey: true, imageName: "chain", description: "Steel signal chain finished in gunmetal.", specs: ["316L stainless steel", "Gunmetal finish", "Lobster-claw clasp"])
        ]

        heroProduct = hero
        newDrops = drops
        self.catalog = catalog
    }
}
