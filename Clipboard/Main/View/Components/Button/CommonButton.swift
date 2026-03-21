//
//  CommonButton.swift
//  Clipboard
//
//  Created by crown on 2026/3/14.
//

import SwiftUI

struct CommonButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(title, action: action)
            .focusable(false)
            .controlSize(.regular)
            .buttonStyle(.plain)
            .padding(.horizontal, Const.space10)
            .padding(.vertical, Const.space4)
            .background(isHovered ? .gray.opacity(0.1) : .clear)
            .clipShape(.rect(cornerRadius: Const.settingsRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Const.settingsRadius)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1.0)
            }
            .onHover { isHovered = $0 }
    }
}

#Preview {
    CommonButton(title: String(localized: .settingKeyboardReset)) {}
        .padding()
}
