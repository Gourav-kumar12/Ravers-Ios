//
//  Font+Theme.swift
//  Raverse-ios
//
//  Typography helpers. For now these use the system font; once the brand
//  fonts (Syne / Hanken Grotesk / Space Mono) are added to Resources/Fonts
//  and registered in Info.plist, swap the implementations to .custom(...).
//

import SwiftUI

extension Font {
    /// Big display headline (maps to Syne ExtraBold later).
    static func rvDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black)
    }

    /// Body copy (maps to Hanken Grotesk later).
    static func rvBody(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }

    /// Mono label / eyebrow / ticket text (maps to Space Mono later).
    static func rvMono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}
