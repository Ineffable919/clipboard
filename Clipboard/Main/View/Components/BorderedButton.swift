//
//  BorderedButton.swift
//  Clipboard
//
//  Created by crown on 2026/1/5.
//

import SwiftUI

struct BorderedButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(title, action: action)
            .font(.system(size: Const.space12, weight: .regular))
            .foregroundStyle(.primary)
            .focusable(false)
            .buttonStyle(.borderless)
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
    BorderedButton(title: "重置快捷方式为默认...") {}
        .padding()
}
