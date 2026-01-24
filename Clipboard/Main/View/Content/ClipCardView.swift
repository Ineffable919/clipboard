//
//  ClipCardView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import SwiftUI

struct ClipCardView: View {
    private static let cardShadowColor = Color(hex: "#30689C").opacity(0.1)

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

        cardContent
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
                color: isSelected ? .clear : ClipCardView.cardShadowColor,
                radius: isSelected ? 0 : 4,
                x: 0,
                y: isSelected ? 0 : 6
            )
            .padding(Const.space4)
            .contextMenu { contextMenuContent }
            .popover(
                isPresented: Binding(
                    get: { showPreview },
                    set: { showPreviewId = $0 ? model.id : nil }
                )
            ) {
                PreviewPopoverView(model: model)
            }
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            CardHeadView(model: model)
                .id("\(model.id ?? 0)-\(model.group)-\(model.timestamp)")

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
                if model.type == .color {
                    Color(hex: model.attributeString.string)
                } else if !model.isLink || !enableLinkPreview {
                    model.backgroundColor
                }
            }
            .clipShape(Const.contentShape)
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
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(textColor)
                .padding(.bottom, Const.space4)
                .padding(.trailing, Const.space2)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var textAlignment: Alignment {
        model.pasteboardType.isText() ? .topLeading : .top
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

    @ViewBuilder
    private var contextMenuContent: some View {
        Button(
            pasteButtonTitle,
            systemImage: "doc.on.clipboard",
            action: pasteToCode
        )
        .keyboardShortcut(.return, modifiers: [])

        if model.pasteboardType.isText() {
            Button(
                "以纯文本粘贴",
                systemImage: "text.alignleft",
                action: pasteAsPlainText
            )
            .keyboardShortcut(.return, modifiers: plainTextModifiers)
        }

        Button("复制", systemImage: "doc.on.doc", action: copyToClipboard)
            .keyboardShortcut("c", modifiers: [.command])

        Divider()

        if model.pasteboardType.isText() {
            Button("编辑", systemImage: "pencil", action: openEditWindow)
                .keyboardShortcut("e", modifiers: [.command])
        }

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

#Preview {
    @Previewable @State var previewId: PasteboardModel.ID? = nil
    let env = AppEnvironment()
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
        isSelected: false,
        showPreviewId: $previewId,
        quickPasteIndex: 1,
        enableLinkPreview: true,
        searchKeyword: ""
    )
    .environment(env)
    .padding()
}
