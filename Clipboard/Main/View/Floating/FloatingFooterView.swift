//
//  FloatingFooterView.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import SwiftUI

struct FloatingFooterView: View {
    @State private var isSettingsHovered = false
    private let pd = PasteDataStore.main

    private var formattedCount: String {
        NumberFormatter.localizedString(
            from: NSNumber(value: pd.filteredCount),
            number: .decimal
        )
    }

    var body: some View {
        HStack {
            Button {
                SettingWindowController.shared.toggleWindow()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background {
                        RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                            .fill(isSettingsHovered ? Color.secondary.opacity(0.1) : .clear)
                    }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isSettingsHovered = hovering
            }

            Spacer()

            Text("\(formattedCount) 个项目")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)

            Spacer()

            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, FloatConst.horizontalPadding)
    }
}

#Preview {
    FloatingFooterView()
        .frame(width: 420, height: 44)
        .background(Color.gray.opacity(0.1))
}
