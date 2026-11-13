//
//  PasteTargetIllustration.swift
//  Clipboard
//
//  Created by crown on 2026/8/14
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
