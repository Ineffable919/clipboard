//
//  ClipCardView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import SwiftUI

struct ClipCardView: View {
    var model: PasteboardModel
    var isSelected: Bool
    @Binding var showPreview: Bool
    var isHistoryFocused: Bool
    var quickPasteIndex: Int?
    var onRequestDelete: (() -> Void)?

    private let vm = ClipboardViewModel.shard
    private let controller = ClipMainWindowController.shared
    @AppStorage("enableLinkPreview") private var enableLinkPreview: Bool =
        PasteUserDefaults.enableLinkPreview

    var body: some View {
        ZStack(alignment: .bottom) {
            if isSelected {
                RoundedRectangle(
                    cornerRadius: Const.radius + 4,
                    style: .continuous
                )
                .strokeBorder(
                    isSelected ? selectionColor : Color.clear,
                    lineWidth: isSelected ? 4 : 0
                )
                .padding(-4)
            }
            VStack(spacing: 0) {
                CardHeadView(model: model)

                CardContentView(model: model)
                    .padding(contetPadding)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: textAlignment
                    )
                    .background {
                        if model.url == nil
                            || !enableLinkPreview
                        {
                            model.backgroundColor
                        }
                    }
                    .clipShape(Const.contentShape)
            }

            CardBottomView(model: model)
        }
        .overlay(alignment: .bottomTrailing) {
            if let index = quickPasteIndex {
                quickPasteIndexBadge(index: index)
            }
        }
        .frame(width: Const.cardSize, height: Const.cardSize)
        .padding(4)
        .clipShape(
            RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
        )
        .shadow(color: .accentColor.opacity(0.08), radius: 2.0, x: 0, y: 1)
        .contextMenu(menuItems: {
            contextMenuContent
        })
        .popover(isPresented: $showPreview) {
            PreviewPopoverView(model: model)
        }
    }

    @ViewBuilder
    private func quickPasteIndexBadge(index: Int) -> some View {
        let (baseColor, textColor) = model.colors()
        Text("\(index)")
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundColor(textColor)
            .frame(width: 16, height: 16)
            .background(Circle().fill(baseColor))
            .padding(.bottom, 4)
            .padding(.trailing, 4)
            .transition(.scale.combined(with: .opacity))
    }

    private var textAlignment: Alignment {
        model.pasteboardType.isText() ? .topLeading : .top
    }

    private var contetPadding: CGFloat {
        if model.pasteboardType.isImage()
            || (model.url != nil && enableLinkPreview)
        {
            return 0.0
        }
        return Const.space
    }

    private var selectionColor: Color {
        isHistoryFocused ? Color.accentColor.opacity(0.8) : Color.gray
    }

    private var pasteButtonTitle: String {
        if let appName = controller.preApp?.localizedName {
            return "粘贴到 " + appName
        }
        return "粘贴"
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button(action: pasteToCode) {
            Label(pasteButtonTitle, systemImage: "doc.on.clipboard")
        }
        .keyboardShortcut(.return, modifiers: [])

        if model.pasteboardType.isText() {
            Button(action: pasteAsPlainText) {
                Label("以纯文本粘贴", systemImage: "text.alignleft")
            }
            .keyboardShortcut(.return, modifiers: plainTextModifiers)
        }

        Button(action: copyToClipboard) {
            Label("复制", systemImage: "doc.on.doc")
        }
        .keyboardShortcut("c", modifiers: [.command])

        Divider()

        Button(action: deleteItem) {
            Label("删除", systemImage: "trash")
        }
        .keyboardShortcut(.delete, modifiers: [.command])

        Divider()

        Button(action: togglePreview) {
            Label("预览", systemImage: "eye")
        }
        .keyboardShortcut(.space, modifiers: [])
    }

    private var plainTextModifiers: EventModifiers {
        KeyHelper.eventModifiers(from: PasteUserDefaults.plainTextModifier)
    }

    // MARK: - Context Menu Actions

    private func pasteToCode() { vm.pasteAction(item: model) }
    private func pasteAsPlainText() {
        vm.pasteAction(item: model, isAttribute: false)
    }
    private func copyToClipboard() { vm.copyAction(item: model) }
    private func deleteItem() { onRequestDelete?() }
    private func togglePreview() { showPreview = !showPreview }
}

#Preview {
    let data = "Clipboard".data(using: .utf8)
    ClipCardView(
        model: PasteboardModel(
            pasteboardType: PasteboardType.string,
            data: data!,
            showData: Data(),
            timestamp: 1_728_878_384_000,
            appPath: "/Applications/WeChat.app",
            appName: "微信",
            searchText: "",
            length: 9,
            group: -1
        ),
        isSelected: false,
        showPreview: .constant(false),
        isHistoryFocused: false,
        quickPasteIndex: 1
    )
}
