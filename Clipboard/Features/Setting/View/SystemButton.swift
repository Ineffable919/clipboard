//
//  SystemButton.swift
//  Clipboard
//

import SwiftUI

struct SystemButton: View {
    private let label: Text
    let action: () -> Void

    init(title: LocalizedStringResource, action: @escaping () -> Void) {
        label = Text(title)
        self.action = action
    }

    init(title: String, action: @escaping () -> Void) {
        label = Text(title)
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            label
        }
            .focusable(false)
            .buttonStyle(.bordered)
            .controlSize(.regular)
    }
}

#Preview {
    SystemButton(title: .keyboardResetMore) {}
        .padding()
}
