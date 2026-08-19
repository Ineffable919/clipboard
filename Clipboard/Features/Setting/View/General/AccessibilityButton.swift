//
//  AccessibilityButton.swift
//  Clipboard
//

import SwiftUI

struct AccessibilityButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Const.space6) {
                ZStack {
                    Circle()
                        .fill(Color(nsColor: .systemRed))
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: Const.iconSize16, height: Const.iconSize16)
                .accessibilityHidden(true)

                Text(.settingGeneralEnableAccessibility)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Const.space10)
            .padding(.vertical, Const.space6)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: Const.space8)
            )
        }
        .buttonStyle(.plain)
    }
}
