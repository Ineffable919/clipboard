//
//  TextEditView.swift
//  Clipboard
//
//  Created by crown on 2025/12/28.
//

import AppKit
import SwiftUI

struct TextEditView: View {
    @Bindable var state: EditWindowState
    let onCancel: () -> Void
    let onSave: (NSAttributedString) -> Void

    @State private var textEditor: RichTextEditorCoordinator?

    var body: some View {
        VStack(spacing: 0) {
            EditToolbar(
                onCancel: onCancel,
                onSave: {
                    onSave(textEditor?.currentContent() ?? state.editedContent)
                },
                onFormat: applyFormat
            )

            Divider()

            RichTextEditor(
                text: $state.editedContent,
                coordinator: $textEditor
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            StatisticsBar(statistics: state.statistics)
        }
        .frame(minWidth: 400, minHeight: 300)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(.rect(cornerRadius: Const.radius))
    }

    private func applyFormat(_ action: FormatAction) {
        textEditor?.applyFormat(action)
    }
}

// MARK: - FormatAction

enum FormatAction {
    case bold
    case italic
    case underline
    case strikethrough
}

// MARK: - EditToolbar

struct EditToolbar: View {
    let onCancel: () -> Void
    let onSave: () -> Void
    let onFormat: (FormatAction) -> Void

    var body: some View {
        HStack(spacing: Const.space16) {
            BorderedButton(title: "取消", action: onCancel)

            Spacer()

            HStack(spacing: Const.space8) {
                FormatButton(symbol: "bold", action: { onFormat(.bold) })
                FormatButton(symbol: "italic", action: { onFormat(.italic) })
                FormatButton(
                    symbol: "underline",
                    action: { onFormat(.underline) }
                )
                FormatButton(
                    symbol: "strikethrough",
                    action: { onFormat(.strikethrough) }
                )
            }

            Spacer()

            Button(action: onSave) {
                Text("保存")
                    .font(.system(size: Const.space12, weight: .light))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Const.space10)
                    .padding(.vertical, Const.space4)
                    .background(Color.accentColor)
                    .clipShape(.rect(cornerRadius: Const.settingsRadius))
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
        .padding(.horizontal, Const.space10)
        .padding(.vertical, Const.space10)
    }
}

// MARK: - FormatButton

struct FormatButton: View {
    let symbol: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6.0)
                        .fill(
                            isHovered ? Color.gray.opacity(0.15) : Color.clear
                        )
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - StatisticsBar

struct StatisticsBar: View {
    let statistics: TextStatistics

    var body: some View {
        HStack {
            Text(statistics.displayString)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, Const.space12)
        .padding(.vertical, Const.space8)
    }
}

// MARK: - Preview

#Preview {
    let data = "Hello World\nThis is a test.".data(using: .utf8)!
    let model = PasteboardModel(
        pasteboardType: .string,
        data: data,
        showData: data,
        timestamp: Int64(Date().timeIntervalSince1970),
        appPath: "",
        appName: "Preview",
        searchText: "Hello World\nThis is a test.",
        length: 27,
        group: -1,
        tag: "string"
    )
    let state = EditWindowState(model: model)

    TextEditView(
        state: state,
        onCancel: {},
        onSave: { _ in }
    )
    .frame(width: 400, height: 300)
}
