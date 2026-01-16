//
//  FloatingCardView.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import SwiftUI

struct FloatingCardView: View {
    let model: PasteboardModel
    let isSelected: Bool
    @Binding var showPreviewId: PasteboardModel.ID?
    let quickPasteIndex: Int?
    let searchKeyword: String
    var onTap: (() -> Void)?
    var onRequestDelete: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let showPreview = showPreviewId == model.id

        Button {
            onTap?()
        } label: {
            cardContent
        }
        .padding(.vertical, Const.space2)
        .buttonStyle(
            FloatingCardButtonStyle(
                isSelected: isSelected,
                selectionColor: selectionColor
            )
        )
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
        HStack(alignment: .center, spacing: Const.space4) {
            appIconView
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: Const.space4) {
                FloatContentView
            }
            .padding(Const.space4)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: model.pasteboardType.isText() ? .leading : .center
            )

            VStack(alignment: .trailing, spacing: Const.space4) {
                Text(model.timestamp.timeAgo)
                    .font(.system(size: 10))
                    .foregroundStyle(model.colors().1)
                Spacer()
                if let index = quickPasteIndex {
                    quickPasteBadge(index: index)
                }
            }
            .padding(.vertical, Const.space6)
            .padding(.trailing, Const.space6)
        }
        .padding(.leading, Const.space12)
        .frame(
            maxWidth: .infinity,
            minHeight: FloatConst.cardHeight,
            maxHeight: FloatConst.cardHeight
        )
        .background {
            cardBackground
        }
    }

    @ViewBuilder
    private var appIconView: some View {
        AppIconImageView(appPath: model.appPath)
            .clipShape(.rect(cornerRadius: Const.radius))
    }

    @ViewBuilder
    private var FloatContentView: some View {
        switch model.type {
        case .image:
            FloatingImageThumbnailView(model: model)
                .clipShape(.rect(cornerRadius: 6.0))
        case .color:
            Text(model.attributeString.string)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
        case .file:
            if let paths = model.cachedFilePaths {
                if paths.count > 1 {
                    Text("\(paths.count) 个文件")
                } else if let firstPath = paths.first {
                    Text(firstPath)
                        .truncationMode(.head)
                }
            }
        case .rich:
            if model.hasBgColor {
                if searchKeyword.isEmpty {
                    Text(model.attributed())
                } else {
                    Text(model.highlightedRichText(keyword: searchKeyword))
                }
            } else {
                if searchKeyword.isEmpty {
                    Text(model.attributeString.string)
                        .textCardStyle()
                } else {
                    Text(model.highlightedPlainText(keyword: searchKeyword))
                }
            }
        default:
            if searchKeyword.isEmpty {
                Text(model.attributeString.string)
            } else {
                Text(model.highlightedPlainText(keyword: searchKeyword))
            }
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if model.type == .color {
            RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                .fill(Color(hex: model.attributeString.string))
        } else {
            RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                .fill(model.backgroundColor)
        }
    }

    private func quickPasteBadge(index: Int) -> some View {
        Text(index, format: .number)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(model.colors().1)
    }

    private var selectionColor: Color {
        env.focusView == .history ? .accentColor.opacity(0.8) : .gray
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button("粘贴", systemImage: "doc.on.clipboard", action: pasteToApp)
            .keyboardShortcut(.return, modifiers: [])

        if model.pasteboardType.isText() {
            Button(
                "以纯文本粘贴",
                systemImage: "text.alignleft",
                action: pasteAsPlainText
            )
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

    // MARK: - Actions

    private func pasteToApp() {
        env.actions.paste(model)
    }

    private func pasteAsPlainText() {
        env.actions.paste(model, isAttribute: false)
    }

    private func copyToClipboard() {
        env.actions.copy(model)
    }

    private func deleteItem() {
        onRequestDelete?()
    }

    private func togglePreview() {
        showPreviewId = showPreviewId == model.id ? nil : model.id
    }

    private func openEditWindow() {
        EditWindowController.shared.openWindow(with: model)
    }
}

// MARK: - Floating Card Button Style

private struct FloatingCardButtonStyle: ButtonStyle {
    let isSelected: Bool
    let selectionColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .clipShape(.rect(cornerRadius: Const.radius))
            .overlay {
                if isSelected {
                    RoundedRectangle(
                        cornerRadius: Const.radius + 2,
                        style: .continuous
                    )
                    .strokeBorder(selectionColor, lineWidth: 2)
                    .padding(-2)
                }
            }
            .shadow(
                color: isSelected ? .clear : Const.cardShadowColor,
                radius: isSelected ? 0 : 6,
                x: 0,
                y: isSelected ? 0 : 3
            )
    }
}

// MARK: - App Icon Image View

private struct AppIconImageView: View {
    let appPath: String
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: appPath) {
            guard !appPath.isEmpty else { return }
            icon = NSWorkspace.shared.icon(forFile: appPath)
        }
    }
}

// MARK: - Floating Image Thumbnail View

private struct FloatingImageThumbnailView: View {
    let model: PasteboardModel
    @State private var thumbnail: NSImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task {
            guard thumbnail == nil, !isLoading else { return }
            isLoading = true
            thumbnail = await model.loadThumbnail()
            isLoading = false
        }
    }
}

#Preview {
    @Previewable @State var previewId: PasteboardModel.ID? = nil
    let env = AppEnvironment()
    let data = "你好".data(using: .utf8) ?? Data()
    FloatingCardView(
        model: PasteboardModel(
            pasteboardType: .string,
            data: data,
            showData: data,
            timestamp: Int64(Date().timeIntervalSince1970),
            appPath: "/Applications/Wechat.app",
            appName: "微信",
            searchText: "你好",
            length: 2,
            group: -1,
            tag: "string"
        ),
        isSelected: false,
        showPreviewId: $previewId,
        quickPasteIndex: 1,
        searchKeyword: "",
        onTap: {}
    )
    .environment(env)
    .padding()
    .frame(width: 370)
}
