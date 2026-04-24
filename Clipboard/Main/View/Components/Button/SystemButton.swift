//
//  SystemButton.swift
//  Clipboard
//
//  Created by crown on 2026/1/5.
//

import SwiftUI

struct SystemButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .focusable(false)
            .controlSize(.regular)
            .buttonStyle(.plain)
            .padding(.horizontal, Const.space10)
            .padding(.vertical, Const.space4)
            .background(.gray.opacity(0.1))
            .clipShape(.rect(cornerRadius: Const.settingsRadius))
    }
}

#Preview {
    SystemButton(title: String(localized: .settingKeyboardResetMore)) {}
        .padding()
}
