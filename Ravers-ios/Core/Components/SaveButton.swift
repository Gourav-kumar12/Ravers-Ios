//
//  SaveButton.swift
//  Raverse-ios
//
//  The circular bookmark button on product/event cards.
//

import SwiftUI

struct SaveButton: View {
    @State private var isSaved = false

    var body: some View {
        Button {
            isSaved.toggle()
        } label: {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.06), in: Circle())
                .overlay(Circle().stroke(Color.rvBorder))
        }
    }
}

#Preview {
    ZStack {
        Color.rvBackground.ignoresSafeArea()
        SaveButton()
    }
}
