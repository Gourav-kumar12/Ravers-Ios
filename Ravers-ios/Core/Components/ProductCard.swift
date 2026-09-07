//
//  ProductCard.swift
//  Raverse-ios
//
//  A single product tile for the catalog grid / carousels.
//  TODO: swap the placeholder rectangle for AsyncImage / Image(product.imageName).
//

import SwiftUI

struct ProductCard: View {
    
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.rvSurface)
                    .aspectRatio(1, contentMode: .fit)
                if product.isPartnerKey {
                    PartnerKeyTag().padding(10)
                    
                }
            }

            Text(product.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.rvText)

            HStack(spacing: 8) {
                Text("₹\(product.price)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.rvText)
                if let was = product.compareAtPrice {
                    Text("₹\(was)")
                        .font(.system(size: 13))
                        .strikethrough()
                        .foregroundStyle(Color.rvTextMuted)
                }
            }
        }
    }
}
