//
//  PasteTargetIllustration.swift
//  Clipboard
//

import SwiftUI

struct PasteTargetIllustration: View {
    let mode: PasteTargetMode

    var body: some View {
        Image(
            mode == .toApp
                ? .app
                : .clip
        )
        .resizable()
        .interpolation(.high)
        .scaledToFit()
        .accessibilityHidden(true)
    }
}
