//
//  PreviewPopoverView.swift
//  Clipboard
//
//  Created by crown on 2025/10/20.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VisionKit
import WebKit

struct PreviewPopoverView: View {
    static let defaultWidth: CGFloat = 400.0
    static let defaultHeight: CGFloat = 220.0

    let model: PasteboardModel
    var onClose: (() -> Void)?

    @Environment(AppEnvironment.self) private var env
    @AppStorage(PrefKey.enableLinkPreview.rawValue)
    private var enableLinkPreview: Bool = PasteUserDefaults.enableLinkPreview

    @State private var defaultBrowserName: String?
    @State private var defaultAppForFile: String?
    @State private var fileSize: String?
    @State private var cachedTextStatistics: TextStatistics?
    @State private var appIcon: NSImage?

    private var isSingleFile: Bool {
        model.type == .file && model.fileSize() == 1
    }

    var body: some View {
        FocusableContainer(onInteraction: {
            Task { @MainActor in
                env.focusView = .popover
            }
        }) {
            VStack(alignment: .leading, spacing: Const.space12) {
                PreviewHeaderView(
                    model: model,
                    appIcon: appIcon,
                    isSingleFile: isSingleFile,
                    defaultAppForFile: defaultAppForFile,
                    onClose: onClose,
                    onEdit: { EditWindowController.shared.openWindow(with: model) }
                )
                .frame(height: 24)

                PreviewContentSwitcher(
                    model: model,
                    enableLinkPreview: enableLinkPreview
                )
                .clipShape(.rect(cornerRadius: Const.radius))
                .shadow(radius: 0.5)
                .frame(maxHeight: .infinity)

                PreviewFooterView(
                    model: model,
                    enableLinkPreview: enableLinkPreview,
                    isSingleFile: isSingleFile,
                    fileSize: fileSize,
                    defaultBrowserName: defaultBrowserName,
                    cachedTextStatistics: cachedTextStatistics
                )
                .frame(height: 24)
            }
            .padding(Const.space12)
            .frame(
                minWidth: Const.minPreviewWidth,
                maxWidth: Const.maxPreviewWidth,
                minHeight: Const.minPreviewHeight,
                maxHeight: Const.maxPreviewHeight
            )
        }
        .task {
            await loadMetadata()
        }
        .onDisappear {
            if env.focusView != .search {
                env.focusView = .history
            }
        }
    }

    private func loadMetadata() async {
        if !model.appPath.isEmpty {
            appIcon = NSWorkspace.shared.icon(forFile: model.appPath)
        }

        defaultBrowserName = bundleDisplayName(for: NSWorkspace.shared.urlForApplication(toOpen: .html))

        if isSingleFile, let fileUrl = model.cachedFilePaths?.first {
            let url = URL(filePath: fileUrl)

            defaultAppForFile = bundleDisplayName(for: NSWorkspace.shared.urlForApplication(toOpen: url))

            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path()),
               let size = attributes[.size] as? Int64
            {
                fileSize = size.formatted(.byteCount(style: .file))
            }
        }

        if model.pasteboardType.isText() {
            cachedTextStatistics = TextStatistics(from: model.attributeString.string)
        }
    }

    private func bundleDisplayName(for appURL: URL?) -> String? {
        guard let appURL, let bundle = Bundle(url: appURL) else { return nil }
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}

// MARK: - PreviewHeaderView

private struct PreviewHeaderView: View {
    let model: PasteboardModel
    let appIcon: NSImage?
    let isSingleFile: Bool
    let defaultAppForFile: String?
    var onClose: (() -> Void)?
    var onEdit: (() -> Void)?

    var body: some View {
        HStack {
            Button {
                onClose?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 20, height: 20)
            }

            Text(model.appName)

            Spacer()

            if model.pasteboardType.isText() {
                CommonButton(
                    title: String(localized: .edit),
                    action: { onEdit?() }
                )
            }

            if isSingleFile,
               let fileUrl = model.cachedFilePaths?.first,
               let defaultApp = defaultAppForFile
            {
                CommonButton(
                    title: String(localized: .openWithApp(defaultApp))
                ) {
                    NSWorkspace.shared.open(URL(filePath: fileUrl))
                }
            }
        }
    }
}

// MARK: - PreviewFooterView

private struct PreviewFooterView: View {
    let model: PasteboardModel
    let enableLinkPreview: Bool
    let isSingleFile: Bool
    let fileSize: String?
    let defaultBrowserName: String?
    let cachedTextStatistics: TextStatistics?

    private var shouldShowStatistics: Bool {
        if model.type == .link, enableLinkPreview, model.isLink {
            return false
        }
        return model.pasteboardType.isText()
    }

    private var textStatistics: TextStatistics {
        cachedTextStatistics ?? TextStatistics(from: model.attributeString.string)
    }

    var body: some View {
        HStack(spacing: Const.space4) {
            if shouldShowStatistics {
                Text(textStatistics.displayString)
                    .font(.callout)
            } else {
                Text(model.introString())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.head)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Const.space4)
                    .frame(
                        maxWidth: Const.maxPreviewWidth - 128,
                        alignment: .topLeading
                    )
            }
            Spacer()

            if isSingleFile {
                HStack {
                    if let fileSize {
                        Text(fileSize)
                            .foregroundStyle(.secondary)
                    }
                    CommonButton(
                        title: String(localized: .showInFinder),
                        action: openInFinder
                    )
                }
            }

            if model.type == .link,
               enableLinkPreview,
               let browserName = defaultBrowserName
            {
                CommonButton(
                    title: String(localized: .openInApp(browserName)),
                    action: openInBrowser
                )
            }
        }
    }

    private func openInFinder() {
        guard let filePath = model.cachedFilePaths?.first else { return }
        NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: "")
    }

    private func openInBrowser() {
        guard let url = model.attributeString.string.asCompleteURL() else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - PreviewContentSwitcher

private struct PreviewContentSwitcher: View {
    let model: PasteboardModel
    let enableLinkPreview: Bool

    var body: some View {
        switch model.type {
        case .link:
            PreviewLinkView(model: model, enableLinkPreview: enableLinkPreview)
        case .color:
            PreviewColorView(model: model)
        case .string:
            PreviewTextView(model: model)
        case .rich:
            PreviewRichTextView(model: model)
        case .image:
            PreviewImageView(model: model)
        case .file:
            PreviewFileView(model: model)
        case .none:
            PreviewEmptyView()
        }
    }
}

// MARK: - PreviewLinkView

private struct PreviewLinkView: View {
    let model: PasteboardModel
    let enableLinkPreview: Bool

    var body: some View {
        if enableLinkPreview, model.isLink,
           let url = model.attributeString.string.asCompleteURL()
        {
            if #available(macOS 26.0, *) {
                WebContentView(url: url)
            } else {
                UIWebView(url: url)
            }
        } else {
            PreviewTextView(model: model)
        }
    }
}

// MARK: - PreviewColorView

private struct PreviewColorView: View {
    let model: PasteboardModel

    private var extractedText: String {
        model.attributeString.string
    }

    var body: some View {
        let (_, textColor) = model.colors()
        if !extractedText.isEmpty {
            VStack(alignment: .center) {
                Text(extractedText)
                    .font(.title2)
                    .foregroundStyle(textColor)
            }
            .frame(
                maxWidth: Const.maxPreviewWidth,
                maxHeight: Const.maxPreviewHeight,
                alignment: .center
            )
            .background(Color(NSColor(hex: extractedText)))
        }
    }
}

// MARK: - PreviewTextView

private struct PreviewTextView: View {
    let model: PasteboardModel

    private var extractedText: String {
        model.attributeString.string
    }

    var body: some View {
        if model.length > Const.maxTextSize {
            LargeTextView(model: model)
                .frame(
                    width: Const.maxPreviewWidth - 32,
                    height: Const.maxContentHeight
                )
        } else {
            ZStack {
                Color(.controlBackgroundColor)
                ScrollView(.vertical) {
                    Text(extractedText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Const.space8)
                }
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: Const.maxPreviewWidth, alignment: .topLeading)
        }
    }
}

// MARK: - PreviewRichTextView

private struct PreviewRichTextView: View {
    let model: PasteboardModel

    var body: some View {
        if model.length > Const.maxRichTextSize {
            LargeTextView(model: model)
                .frame(
                    width: Const.maxPreviewWidth - 32,
                    height: Const.maxContentHeight
                )
        } else {
            ZStack {
                model.backgroundColor
                ScrollView(.vertical) {
                    PreviewRichTextContent(model: model)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Const.space8)
                }
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: Const.maxPreviewWidth, alignment: .topLeading)
        }
    }
}

// MARK: - PreviewRichTextContent

private struct PreviewRichTextContent: View {
    let model: PasteboardModel

    var body: some View {
        let attr =
            NSAttributedString(
                with: model.data,
                type: model.pasteboardType
            ) ?? NSAttributedString()
        if model.hasBgColor {
            Text(AttributedString(attr))
                .textSelection(.enabled)
        } else {
            Text(attr.string)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - PreviewImageView

private struct PreviewImageView: View {
    let model: PasteboardModel

    var body: some View {
        ZStack {
            CheckerboardBackground()
            LiveTextImageView(imageData: model.data)
                .frame(
                    maxWidth: Const.maxPreviewWidth - Const.space12 * 2,
                    maxHeight: Const.maxContentHeight
                )
        }
    }
}

// MARK: - PreviewFileView

private struct PreviewFileView: View {
    let model: PasteboardModel

    var body: some View {
        Group {
            if let paths = model.cachedFilePaths, paths.count == 1, let firstPath = paths.first {
                QuickLookPreview(
                    url: URL(filePath: firstPath),
                    maxWidth: Const.maxPreviewWidth - 32,
                    maxHeight: Const.maxContentHeight
                )
            } else {
                Image(systemName: "folder")
                    .resizable()
                    .foregroundStyle(Color.accentColor.opacity(0.8))
                    .frame(width: 144, height: 144, alignment: .center)
            }
        }
        .frame(
            width: Const.maxPreviewWidth - 32,
            height: Const.maxContentHeight
        )
    }
}

// MARK: - PreviewEmptyView

private struct PreviewEmptyView: View {
    var body: some View {
        Text(.noPreview)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(
                width: PreviewPopoverView.defaultWidth,
                height: PreviewPopoverView.defaultHeight,
                alignment: .center
            )
    }
}

// MARK: - FocusableContainer

struct FocusableContainer<Content: View>: NSViewRepresentable {
    let onInteraction: () -> Void
    @ViewBuilder let content: Content

    func makeNSView(context _: Context) -> NSHostingView<Content> {
        InterceptingHostingView(
            rootView: content,
            onInteraction: onInteraction
        )
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context _: Context) {
        nsView.rootView = content
    }
}

class InterceptingHostingView<Content: View>: NSHostingView<Content> {
    private let onInteraction: () -> Void

    init(rootView: Content, onInteraction: @escaping () -> Void) {
        self.onInteraction = onInteraction
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @available(*, unavailable)
    required init(rootView _: Content) {
        fatalError("init(rootView:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hitView = super.hitTest(point)
        if hitView != nil, NSEvent.pressedMouseButtons == 1 {
            onInteraction()
        }
        return hitView
    }

    deinit {}
}

// MARK: - Preview

#Preview {
    let env = AppEnvironment()
    let data = Data("https://www.apple.com.cn".utf8)

    PreviewPopoverView(
        model: PasteboardModel(
            pasteboardType: .string,
            data: data,
            showData: data,
            timestamp: Int64(Date().timeIntervalSince1970),
            appPath: "/Applications/WeChat.app",
            appName: "Preview",
            searchText: "",
            length: 0,
            group: -1,
            tag: "string"
        ),
        onClose: {}
    )
    .environment(env)
    .frame(width: 800, height: 600)
}
