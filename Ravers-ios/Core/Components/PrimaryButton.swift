//
//  PrimaryButton.swift
//  Raverse-ios
//
//  The app's primary call-to-action — a full-width red gradient button.
//  Used for "SEND CODE", "ADD TO VAULT", "VIEW THE DROP", etc.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(RVGradient.redCTA)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

#Preview {
    ZStack {
        Color.rvBackground.ignoresSafeArea()
        PrimaryButton(title: "SEND CODE") {}
            .padding()
    }
}
