//
//  ToggleRow.swift
//  Clipboard
//
//  Created by crown on 2026/3/21
//

import SwiftUI

// MARK: - 通用开关行组件

struct ToggleRow: View {
    @Binding var isEnabled: Bool
    let title: LocalizedStringResource

    var body: some View {
        HStack(alignment: .center, spacing: Const.space12) {
            RoundedRectangle(cornerRadius: Const.space6)
                .fill(isEnabled ? Color.accentColor : Color.primary.opacity(0.08))
                .frame(width: Const.iconSize16, height: Const.iconSize16)
                .overlay {
                    if isEnabled {
                        Image(systemName: "checkmark")
                            .font(.system(size: Const.space10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .onTapGesture {
                    isEnabled.toggle()
                }

            Text(title)

            Spacer()
        }
        .padding(.vertical, Const.space4)
        .contentShape(Rectangle())
        .onTapGesture {
            isEnabled.toggle()
        }
    }
}
