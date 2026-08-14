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
                ? .pasteApp
                : .pasteClipboard
        )
        .resizable()
        .interpolation(.high)
        .scaledToFit()
        .accessibilityHidden(true)
    }
}
