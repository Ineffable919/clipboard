//
//  SystemButton.swift
//  Clipboard
//

import SwiftUI

struct SystemButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .focusable(false)
            .buttonStyle(.bordered)
            .controlSize(.regular)
    }
}

#Preview {
    SystemButton(title: String(localized: .settingKeyboardResetMore)) {}
        .padding()
}
