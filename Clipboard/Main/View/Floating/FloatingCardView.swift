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
    var onRequestDelete: (() -> Void)?

    @Environment(AppEnvironment.self) private var env

    private var modelColors: (Color, Color) {
        model.colors()
    }

    private var isTextType: Bool {
        model.pasteboardType.isText()
    }

    private var showPreview: Binding<Bool> {
        Binding(
            get: { showPreviewId == model.id },
            set: { showPreviewId = $0 ? model.id : nil }
        )
    }

    var body: some View {
        cardContent
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
            .padding(Const.space2)
            .contextMenu { contextMenuContent }
            .popover(isPresented: showPreview, arrowEdge: .leading) {
                PreviewPopoverView(
                    model: model,
                    onClose: { showPreviewId = nil }
                )
            }
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: Const.space10) {
            AppIconImageView(appPath: model.appPath)
                .padding(.leading, Const.space6)

            floatContentView
                .padding(.vertical, Const.space4)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: isTextType || model.pasteboardType.isFile()
                        ? .leading : .center
                )

            VStack(alignment: .trailing, spacing: Const.space4) {
                Text(
                    model.timestamp.timeAgo(
                        relativeTo: TimeManager.shared.currentTime
                    )
                )
                .font(.system(size: 10))
                .foregroundStyle(modelColors.1)
                Spacer()
                if let index = quickPasteIndex {
                    quickPasteBadge(index: index)
                }
            }
            .padding(.vertical, Const.space6)
            .padding(.trailing, Const.space6)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: FloatConst.cardHeight,
            maxHeight: FloatConst.cardHeight
        )
        .background {
            if model.type == .color {
                Color(hex: model.attributeString.string)
            } else {
                model.backgroundColor
            }
        }
        .clipShape(.rect(cornerRadius: Const.radius))
    }

    @ViewBuilder
    private var floatContentView: some View {
        switch model.type {
        case .image:
            FloatingImageThumbnailView(model: model)
                .clipShape(.rect(cornerRadius: 6.0))
        case .color:
            Text(model.attributeString.string)
                .font(.system(size: 14.0, weight: .medium, design: .monospaced))
                .foregroundStyle(modelColors.1)
        case .file:
            fileContentView
        case .rich:
            richTextContentView
        default:
            plainTextContentView
        }
    }

    @ViewBuilder
    private var fileContentView: some View {
        if let paths = model.cachedFilePaths {
            if paths.count > 1 {
                Text("\(paths.count) 个文件")
            } else if let firstPath = paths.first {
                Text(firstPath)
                    .truncationMode(.head)
            }
        }
    }

    @ViewBuilder
    private var richTextContentView: some View {
        if model.hasBgColor {
            if searchKeyword.isEmpty {
                Text(model.attributed())
            } else {
                Text(model.highlightedRichText(keyword: searchKeyword))
            }
        } else {
            plainTextContentView
        }
    }

    @ViewBuilder
    private var plainTextContentView: some View {
        if searchKeyword.isEmpty {
            Text(model.attributeString.string)
        } else {
            Text(model.highlightedPlainText(keyword: searchKeyword))
        }
    }

    private func quickPasteBadge(index: Int) -> some View {
        Text(index, format: .number)
            .font(.system(size: 10, weight: .regular, design: .rounded))
            .foregroundStyle(modelColors.1)
    }

    private var selectionColor: Color {
        env.focusView == .history ? .accentColor.opacity(0.8) : .gray
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button("粘贴", systemImage: "doc.on.clipboard", action: pasteToApp)
            .keyboardShortcut(.return, modifiers: [])

        if isTextType {
            Button(
                "以纯文本粘贴",
                systemImage: "text.alignleft",
                action: pasteAsPlainText
            )
        }

        Button("复制", systemImage: "doc.on.doc", action: copyToClipboard)
            .keyboardShortcut("c", modifiers: [.command])

        Divider()

        if isTextType {
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
        ClipActionService.shared.paste(model)
    }

    private func pasteAsPlainText() {
        ClipActionService.shared.paste(model, isAttribute: false)
    }

    private func copyToClipboard() {
        ClipActionService.shared.copy(model)
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
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
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
    @State private var loadingTask: Task<Void, Never>?

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
        .task(id: model.uniqueId) {
            await loadImage()
        }
        .onDisappear {
            loadingTask?.cancel()
        }
    }

    private func loadImage() async {
        loadingTask?.cancel()

        isLoading = true
        thumbnail = nil

        loadingTask = Task {
            let loadedImage = await model.loadThumbnail()

            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            thumbnail = loadedImage
            isLoading = false
        }

        await loadingTask?.value
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
            appPath: "/Applications/Google Chrome.app",
            appName: "微信",
            searchText: "你好",
            length: 2,
            group: -1,
            tag: "string"
        ),
        isSelected: false,
        showPreviewId: $previewId,
        quickPasteIndex: 1,
        searchKeyword: ""
    )
    .environment(env)
    .padding()
    .frame(width: 370)
}
