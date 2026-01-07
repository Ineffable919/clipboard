//
//  ClipCardView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import SwiftUI

struct ClipCardView: View {
    let model: PasteboardModel
    let isSelected: Bool
    @Binding var showPreviewId: PasteboardModel.ID?
    let quickPasteIndex: Int?
    let enableLinkPreview: Bool
    let searchKeyword: String
    var onRequestDelete: (() -> Void)?

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let showPreview = showPreviewId == model.id

        CardBodyView(
            model: model,
            searchKeyword: searchKeyword,
            enableLinkPreview: enableLinkPreview
        )
        .overlay {
            CardOverlayView(
                model: model,
                isSelected: isSelected,
                quickPasteIndex: quickPasteIndex,
                selectionColor: selectionColor
            )
        }
        .frame(width: Const.cardSize, height: Const.cardSize)
        .shadow(
            color: isSelected ? .clear : .black.opacity(0.1),
            radius: isSelected ? 0 : 4,
            x: 0,
            y: isSelected ? 0 : 2
        )
        .padding(Const.space4)
        .contextMenu {
            CardContextMenuView(
                model: model,
                pasteButtonTitle: pasteButtonTitle,
                onPaste: pasteToCode,
                onPasteAsPlainText: pasteAsPlainText,
                onCopy: copyToClipboard,
                onEdit: openEditWindow,
                onDelete: deleteItem,
                onPreview: togglePreview
            )
        }
        .popover(
            isPresented: Binding(
                get: { showPreview },
                set: { showPreviewId = $0 ? model.id : nil }
            )
        ) {
            PreviewPopoverView(model: model)
        }
    }

    private var selectionColor: Color {
        env.focusView == .history ? .accentColor.opacity(0.8) : .gray
    }

    private var pasteButtonTitle: String {
        if let appName = env.preApp?.localizedName {
            return "粘贴到 " + appName
        }
        return "粘贴"
    }

    // MARK: - Actions

    private func pasteToCode() { env.actions.paste(model) }

    private func pasteAsPlainText() {
        env.actions.paste(model, isAttribute: false)
    }

    private func copyToClipboard() { env.actions.copy(model) }

    private func deleteItem() { onRequestDelete?() }

    private func togglePreview() {
        showPreviewId = showPreviewId == model.id ? nil : model.id
    }

    private func openEditWindow() {
        EditWindowController.shared.openWindow(with: model)
    }
}

// MARK: - Card Overlay View

private struct CardOverlayView: View {
    let model: PasteboardModel
    let isSelected: Bool
    let quickPasteIndex: Int?
    let selectionColor: Color

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isSelected {
                SelectionBorderView(color: selectionColor)
            }

            if let index = quickPasteIndex {
                QuickPasteIndexBadge(model: model, index: index)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .bottomTrailing
                    )
            }
        }
    }
}

// MARK: - Selection Border View

private struct SelectionBorderView: View {
    let color: Color

    var body: some View {
        RoundedRectangle(
            cornerRadius: Const.radius + 4,
            style: .continuous
        )
        .strokeBorder(color, lineWidth: 4)
        .padding(-4)
    }
}

// MARK: - Quick Paste Index Badge

private struct QuickPasteIndexBadge: View {
    let model: PasteboardModel
    let index: Int

    var body: some View {
        let (_, textColor) = model.colors()
        Text(index, format: .number)
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(textColor)
            .padding(.bottom, Const.space4)
            .padding(.trailing, Const.space4)
            .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Card Body View

private struct CardBodyView: View {
    let model: PasteboardModel
    let searchKeyword: String
    let enableLinkPreview: Bool

    var body: some View {
        VStack(spacing: 0) {
            CardHeadView(model: model)
                .id("\(model.id ?? 0)-\(model.group)-\(model.timestamp)")

            CardContentContainerView(
                model: model,
                searchKeyword: searchKeyword,
                enableLinkPreview: enableLinkPreview
            )
        }
    }
}

// MARK: - Card Content Container View

private struct CardContentContainerView: View {
    let model: PasteboardModel
    let searchKeyword: String
    let enableLinkPreview: Bool

    private var textAlignment: Alignment {
        model.pasteboardType.isText() ? .topLeading : .top
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CardContentView(
                model: model,
                keyword: searchKeyword,
                enableLinkPreview: enableLinkPreview
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: textAlignment
            )

            CardBottomView(
                model: model,
                enableLinkPreview: enableLinkPreview,
                keyword: searchKeyword
            )
        }
        .background {
            CardContentBackgroundView(
                model: model,
                enableLinkPreview: enableLinkPreview
            )
        }
        .clipShape(Const.contentShape)
    }
}

// MARK: - Card Content Background View

private struct CardContentBackgroundView: View {
    let model: PasteboardModel
    let enableLinkPreview: Bool

    var body: some View {
        if model.type == .color {
            Color(nsColor: NSColor(hex: model.attributeString.string))
        } else if !model.isLink || !enableLinkPreview {
            model.backgroundColor
        }
    }
}

// MARK: - Card Context Menu View

private struct CardContextMenuView: View {
    let model: PasteboardModel
    let pasteButtonTitle: String
    let onPaste: () -> Void
    let onPasteAsPlainText: () -> Void
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPreview: () -> Void

    private var plainTextModifiers: EventModifiers {
        KeyCode.eventModifiers(from: PasteUserDefaults.plainTextModifier)
    }

    var body: some View {
        Button(pasteButtonTitle, systemImage: "doc.on.clipboard", action: onPaste)
            .keyboardShortcut(.return, modifiers: [])

        if model.pasteboardType.isText() {
            Button("以纯文本粘贴", systemImage: "text.alignleft", action: onPasteAsPlainText)
                .keyboardShortcut(.return, modifiers: plainTextModifiers)
        }

        Button("复制", systemImage: "doc.on.doc", action: onCopy)
            .keyboardShortcut("c", modifiers: [.command])

        Divider()

        if model.pasteboardType.isText() {
            Button("编辑", systemImage: "pencil", action: onEdit)
                .keyboardShortcut("e", modifiers: [.command])
        }

        Button("删除", systemImage: "trash", action: onDelete)
            .keyboardShortcut(.delete, modifiers: [])

        Divider()

        Button("预览", systemImage: "eye", action: onPreview)
            .keyboardShortcut(.space, modifiers: [])
    }
}

#Preview {
    @Previewable @State var previewId: PasteboardModel.ID? = nil
    let data = "Clipboard".data(using: .utf8)
    ClipCardView(
        model: PasteboardModel(
            pasteboardType: PasteboardType.string,
            data: data!,
            showData: Data(),
            timestamp: 1_728_878_384,
            appPath: "/Applications/WeChat.app",
            appName: "微信",
            searchText: "",
            length: 9,
            group: -1,
            tag: "string"
        ),
        isSelected: true,
        showPreviewId: $previewId,
        quickPasteIndex: 1,
        enableLinkPreview: true,
        searchKeyword: ""
    )
}
