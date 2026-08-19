//
//  WelcomePrimaryButtonStyle.swift
//  Clipboard
//

import SwiftUI

struct WelcomePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(
                WelcomeStyle.accent.opacity(configuration.isPressed ? 0.82 : 1)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: Const.btnRadius, style: .continuous)
            )
    }
}
