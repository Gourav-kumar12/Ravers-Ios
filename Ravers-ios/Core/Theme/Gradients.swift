//
//  Gradients.swift
//  Raverse-ios
//
//  Reusable gradients from the design (background wash + red CTA).
//

import SwiftUI

enum RVGradient {
    /// Full-screen dark background wash with a subtle red bleed.
    static var background: LinearGradient {
        LinearGradient(
            colors: [.black, Color(red: 0.25, green: 0.02, blue: 0.04), .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// The red gradient used on primary buttons.
    static var redCTA: LinearGradient {
        LinearGradient(
            colors: [.rvRed, .rvRedDeep],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
