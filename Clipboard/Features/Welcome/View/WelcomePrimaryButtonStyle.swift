//
//  WelcomePrimaryButtonStyle.swift
//  Clipboard
//

import SwiftUI

#Preview {
    Button(.continue) {}
        .buttonStyle(WelcomePrimaryButtonStyle())
        .frame(width: 100)
        .padding(24)
}

struct WelcomePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(
                WelcomeStyle.accent.opacity(configuration.isPressed ? 0.82 : 1)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: Const.btnRadius, style: .continuous)
            )
    }
}
