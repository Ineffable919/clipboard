//
//  ToggleRow.swift
//  Clipboard
//

import SwiftUI

// MARK: - 通用开关行组件

struct ToggleRow: View {
    @Binding var isEnabled: Bool
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: Const.space12) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isEnabled ? .accentColor : .secondary)
                .font(.system(size: Const.space16))
                .onTapGesture {
                    isEnabled.toggle()
                }

            Text(title)

            Spacer()
        }
        .padding(Const.space4)
        .contentShape(Rectangle())
        .onTapGesture {
            isEnabled.toggle()
        }
    }
}
