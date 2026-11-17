//
//  AccessibilityButton.swift
//  Clipboard
//
//  Created by crown on 2026/8/14
//

import SwiftUI

struct AccessibilityButton: View {
    let action: () -> Void

    private var title: LocalizedStringResource {
        if #available(macOS 27.0, *) {
            .generalAllowDeviceControlAndDataAccess
        } else {
            .generalEnableAccess
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Const.space6) {
                AccessibilityWarningBadge(diameter: Const.iconSize16)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
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
