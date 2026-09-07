//
//  WelcomeView.swift
//  Raverse-ios
//
//  First screen — brand intro before login. (Screen: Auth 1)
//  TODO: brick/hero background, chrome logo, "Enter the Floor" CTA.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        ZStack {
            RVGradient.background.ignoresSafeArea()
            Text("WELCOME")
                .font(.rvDisplay(40))
                .foregroundStyle(Color.rvText)
        }
    }
}

#Preview {
    WelcomeView()
}
