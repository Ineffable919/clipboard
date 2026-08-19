//
//  WelcomeSecondaryButtonStyle.swift
//  Clipboard
//

import SwiftUI

struct WelcomeSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(
                WelcomeStyle.secondaryText(for: colorScheme)
            )
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .opacity(configuration.isPressed ? 0.58 : 1)
    }
}
