//
//  PasteTargetModeRow.swift
//  Clipboard
//

import SwiftUI

/// 粘贴目标模式（单选）
enum PasteTargetMode: Int, CaseIterable {
    case toApp = 0
    case toClipboard = 1

    var title: LocalizedStringResource {
        switch self {
        case .toApp: .settingPasteTargetToApp
        case .toClipboard: .settingPasteTargetToClipboard
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .toApp: .settingPasteTargetToAppDescription
        case .toClipboard: .settingPasteTargetToClipboardDescription
        }
    }
}

// MARK: - 粘贴目标模式行（单选）

struct PasteTargetModeRow: View {
    let mode: PasteTargetMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Const.space12) {
            Image(systemName: isSelected ? "record.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.system(size: Const.space16))
                .onTapGesture {
                    onSelect()
                }

            VStack(alignment: .leading, spacing: Const.space4) {
                Text(mode.title)
                Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(Const.space4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}
