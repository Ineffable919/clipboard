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
    let enableLinkPreview: Bool
    let searchKeyword: String
    var onRequestDelete: (() -> Void)?
    var onPaste: (() -> Void)?
    var onPastePlainText: (() -> Void)?
    var onCopy: (() -> Void)?

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

            FloatingCardContentView(
                model: model,
                enableLinkPreview: enableLinkPreview,
                searchKeyword: searchKeyword
            )
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
                .font(.caption2)
                .foregroundStyle(modelColors.1)
                Spacer()
                if let index = quickPasteIndex {
                    QuickPasteBadgeView(index: index, color: modelColors.1)
                }
            }
            .padding(.vertical, Const.space4)
            .padding(.trailing, Const.space6)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: FloatConst.cardHeight,
            maxHeight: FloatConst.cardHeight
        )
        .background {
            model.backgroundColor
        }
        .clipShape(.rect(cornerRadius: Const.radius))
    }

    private var selectionColor: Color {
        env.focusView == .history ? .accentColor.opacity(0.8) : .gray
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button(String(localized: .paste), systemImage: "doc.on.clipboard", action: pasteToApp)
            .keyboardShortcut(.return, modifiers: [])

        if isTextType {
            Button(
                String(localized: .pastePlain),
                systemImage: "text.alignleft",
                action: pasteAsPlainText
            )
        }

        Button(String(localized: .copy), systemImage: "doc.on.doc", action: copyToClipboard)
            .keyboardShortcut("c", modifiers: [.command])

        Divider()

        if isTextType {
            Button(String(localized: .edit), systemImage: "pencil", action: openEditWindow)
                .keyboardShortcut("e", modifiers: [.command])
        }

        Button(String(localized: .deleteTitle), systemImage: "trash", action: deleteItem)
            .keyboardShortcut(.delete, modifiers: [])

        Divider()

        Button(String(localized: .preview), systemImage: "eye", action: togglePreview)
            .keyboardShortcut(.space, modifiers: [])
    }

    // MARK: - Actions

    private func pasteToApp() {
        onPaste?()
    }

    private func pasteAsPlainText() {
        onPastePlainText?()
    }

    private func copyToClipboard() {
        onCopy?()
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

// MARK: - Floating Card Content View

private struct FloatingCardContentView: View {
    let model: PasteboardModel
    let enableLinkPreview: Bool
    let searchKeyword: String

    private var modelColors: (Color, Color) {
        model.colors()
    }

    var body: some View {
        switch model.type {
        case .image:
            FloatingImageThumbnailView(model: model)
                .clipShape(.rect(cornerRadius: 6.0))
        case .color:
            Text(model.attributeString.string)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .foregroundStyle(modelColors.1)
        case .file:
            FloatingFileContentView(model: model)
        case .rich:
            FloatingRichTextContentView(model: model, searchKeyword: searchKeyword)
        case .link:
            if enableLinkPreview {
                FloatingLinkPreviewView(
                    model: model,
                    searchKeyword: searchKeyword
                )
            } else {
                FloatingPlainTextContentView(model: model, searchKeyword: searchKeyword)
            }
        default:
            FloatingPlainTextContentView(model: model, searchKeyword: searchKeyword)
        }
    }
}

// MARK: - Floating File Content View

private struct FloatingFileContentView: View {
    let model: PasteboardModel

    var body: some View {
        if let paths = model.cachedFilePaths, !paths.isEmpty {
            if paths.count > 1 {
                FloatingMultipleFilesView(paths: paths)
            } else if let firstPath = paths.first {
                FloatingSingleFileView(path: firstPath)
            }
        }
    }
}

// MARK: - Floating Rich Text Content View

private struct FloatingRichTextContentView: View {
    let model: PasteboardModel
    let searchKeyword: String

    var body: some View {
        if model.hasBgColor {
            if searchKeyword.isEmpty {
                Text(model.attributed())
            } else {
                Text(model.highlightedRichText(keyword: searchKeyword))
            }
        } else {
            FloatingPlainTextContentView(model: model, searchKeyword: searchKeyword)
        }
    }
}

// MARK: - Floating Plain Text Content View

private struct FloatingPlainTextContentView: View {
    let model: PasteboardModel
    let searchKeyword: String

    var body: some View {
        if searchKeyword.isEmpty {
            Text(model.attributeString.string)
        } else {
            Text(model.highlightedPlainText(keyword: searchKeyword))
        }
    }
}

// MARK: - Quick Paste Badge View

private struct QuickPasteBadgeView: View {
    let index: Int
    let color: Color

    var body: some View {
        Text(index, format: .number)
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(color)
    }
}

// MARK: - File Content Views

private struct FloatingSingleFileView: View {
    let path: String

    private var fileURL: URL {
        URL(filePath: path)
    }

    private var fileName: String {
        fileURL.lastPathComponent
    }

    var body: some View {
        HStack(spacing: Const.space8) {
            FileThumbnailView(fileURLString: path, maxSize: 32)
                .frame(width: 32, height: 32)

            Text(fileName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)
        }
    }
}

private struct FloatingMultipleFilesView: View {
    let paths: [String]

    var body: some View {
        HStack(spacing: Const.space8) {
            Image(systemName: "folder.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.accentColor.opacity(0.6))
                .frame(width: 24, height: 24)

            Text(.fileCount(paths.count))
                .font(.caption)
                .foregroundStyle(.primary)
        }
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
                Color.clear
                    .frame(width: 28, height: 28)
            }
        }
        .task(id: appPath) {
            icon = await AppIconCache.shared.loadIcon(forPath: appPath)
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
    let data = "Hello".data(using: .utf8) ?? Data()
    FloatingCardView(
        model: PasteboardModel(
            pasteboardType: .string,
            data: data,
            showData: data,
            timestamp: Int64(Date().timeIntervalSince1970),
            appPath: "/Applications/Google Chrome.app",
            appName: "Preview",
            searchText: "Hello",
            length: 2,
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
    .frame(width: 370)
}
