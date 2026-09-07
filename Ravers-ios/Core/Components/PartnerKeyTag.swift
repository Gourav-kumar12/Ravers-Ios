//
//  PartnerKeyTag.swift
//  Raverse-ios
//
//  The red-outlined "PARTNER KEY" pill shown on gated products.
//

import SwiftUI

struct PartnerKeyTag: View {
    var text: String = "PARTNER KEY"

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Color.rvRed)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                Capsule().stroke(Color.rvRed.opacity(0.6), lineWidth: 1)
            )
    }
}

#Preview {
    ZStack {
        Color.rvBackground.ignoresSafeArea()
        PartnerKeyTag()
    }
}
