//
//  AnimatedGradientBackground.swift
//  Ravers-ios
//
//  Created by Gourav  on 13/08/26.
//

import SwiftUI

struct AnimatedGradientBackground: View {

    @State private var animate = false

    var body: some View {

        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.18, green: 0.00, blue: 0.02),
                Color(red: 0.45, green: 0.01, blue: 0.04),
                Color.black,
                Color(red: 0.20, green: 0.00, blue: 0.02)
            ],
            startPoint: animate ? .topLeading : .bottomTrailing,
            endPoint: animate ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .animation(
            .easeInOut(duration: 5)
            .repeatForever(autoreverses: true),
            value: animate
        )
        .onAppear {
            animate = true
        }
    }
}
#Preview {
    AnimatedGradientBackground()
}
