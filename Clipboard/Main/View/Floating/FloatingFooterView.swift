//
//  FloatingFooterView.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import SwiftUI

struct FloatingFooterView: View {
    let itemCount: Int
    @State private var isSettingsHovered = false

    var body: some View {
        HStack {
            Button {
                SettingWindowController.shared.toggleWindow()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSettingsHovered ? Color.secondary.opacity(0.1) : .clear)
                    }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isSettingsHovered = hovering
            }

            Spacer()

            Text("\(itemCount) 个项目")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)

            Spacer()

            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, FloatingConst.horizontalPadding)
    }
}

#Preview {
    FloatingFooterView(itemCount: 39)
        .frame(width: 420, height: 44)
        .background(Color.gray.opacity(0.1))
}
