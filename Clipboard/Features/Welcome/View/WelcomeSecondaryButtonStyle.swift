//
//  WelcomeSecondaryButtonStyle.swift
//  Clipboard
//

import SwiftUI

struct WelcomeSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .foregroundStyle(
                WelcomeStyle.secondaryText(for: colorScheme)
            )
            .frame(maxWidth: .infinity, minHeight: 24)
            .overlay {
                RoundedRectangle(
                    cornerRadius: Const.btnRadius,
                    style: .continuous
                )
                .stroke(WelcomeStyle.border, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
