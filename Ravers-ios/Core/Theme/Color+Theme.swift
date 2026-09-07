//
//  Color+Theme.swift
//  Raverse-ios
//
//  The "Chrome Noir" palette — one source of truth for brand colors.
//  Use these everywhere instead of hard-coding Color(red:green:blue:) in views.
//

import SwiftUI

extension Color {
    /// App background — near-black.
    static let rvBackground = Color(red: 0.024, green: 0.024, blue: 0.027)   // #060607
    /// Slightly lifted surface (cards, fields).
    static let rvSurface    = Color(red: 0.071, green: 0.075, blue: 0.090)   // #121317
    /// Hairline borders / dividers.
    static let rvBorder     = Color.white.opacity(0.12)

    /// Primary accent — the signature red.
    static let rvRed        = Color(red: 0.95, green: 0.02, blue: 0.12)   // #E23B47
    /// Deep red used in gradients.
    static let rvRedDeep    = Color(red: 0.65,  green: 0.02,  blue: 0.05)

    /// Primary text — warm bone white.
    static let rvText       = Color(red: 0.96, green: 0.949, blue: 0.918)    // #F5F2EA
    /// Muted secondary text.
    static let rvTextMuted  = Color(red: 0.769, green: 0.741, blue: 0.675)   // #C4BDAC
}
