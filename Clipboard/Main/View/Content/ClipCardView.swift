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
    @Binding var showPreview: Bool
    let quickPasteIndex: Int?
    let enableLinkPreview: Bool
    let searchKeyword: String
    var onRequestDelete: (() -> Void)?

    @EnvironmentObject private var env: AppEnvironment
    private let controller = ClipMainWindowController.shared

    var body: some View {
        cardContent
            .overlay {
                cardOverlay
            }
            .frame(width: Const.cardSize, height: Const.cardSize)
            .shadow(
                color: isSelected ? .clear : .black.opacity(0.1),
                radius: isSelected ? 0 : 4,
                x: 0,
                y: isSelected ? 0 : 2
            )
            .padding(Const.space4)
            .contextMenu { contextMenuContent }
            .popover(isPresented: $showPreview) {
                PreviewPopoverView(model: model)
            }
    }

    @ViewBuilder
    private var cardOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            if isSelected {
                RoundedRectangle(cornerRadius: Const.radius + 4, style: .continuous)
                    .strokeBorder(selectionColor, lineWidth: 4)
                    .padding(-4)
            }

            if let index = quickPasteIndex {
                quickPasteIndexBadge(index: index)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            CardHeadView(model: model)
                .id("\(model.id ?? 0)-\(model.group)")

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

                CardBottomView(model: model, enableLinkPreview: enableLinkPreview)
            }
            .background {
                if !model.isLink || !enableLinkPreview {
                    model.backgroundColor
                }
            }
            .clipShape(Const.contentShape)
        }
    }

    private func quickPasteIndexBadge(index: Int) -> some View {
        let (_, textColor) = model.colors()
        return Text(index, format: .number)
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(textColor)
            .padding(.bottom, Const.space4)
            .padding(.trailing, Const.space8)
            .transition(.scale.combined(with: .opacity))
    }

    private var textAlignment: Alignment {
        model.pasteboardType.isText() ? .topLeading : .top
    }

    private var selectionColor: Color {
        env.focusView == .history ? .accentColor.opacity(0.8) : .gray
    }

    private var pasteButtonTitle: String {
        if let appName = controller.preApp?.localizedName {
            return "粘贴到 " + appName
        }
        return "粘贴"
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button(pasteButtonTitle, systemImage: "doc.on.clipboard", action: pasteToCode)
            .keyboardShortcut(.return, modifiers: [])

        if model.pasteboardType.isText() {
            Button("以纯文本粘贴", systemImage: "text.alignleft", action: pasteAsPlainText)
                .keyboardShortcut(.return, modifiers: plainTextModifiers)
        }

        Button("复制", systemImage: "doc.on.doc", action: copyToClipboard)
            .keyboardShortcut("c", modifiers: [.command])

        Divider()

        Button("删除", systemImage: "trash", action: deleteItem)
            .keyboardShortcut(.delete, modifiers: [])

        Divider()

        Button("预览", systemImage: "eye", action: togglePreview)
            .keyboardShortcut(.space, modifiers: [])
    }

    private var plainTextModifiers: EventModifiers {
        KeyCode.eventModifiers(from: PasteUserDefaults.plainTextModifier)
    }

    // MARK: - Actions

    private func pasteToCode() { env.actions.paste(model) }
    private func pasteAsPlainText() { env.actions.paste(model, isAttribute: false) }
    private func copyToClipboard() { env.actions.copy(model) }
    private func deleteItem() { onRequestDelete?() }
    private func togglePreview() { showPreview.toggle() }
}

#Preview {
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
        showPreview: .constant(false),
        quickPasteIndex: 1,
        enableLinkPreview: true,
        searchKeyword: ""
    )
}
