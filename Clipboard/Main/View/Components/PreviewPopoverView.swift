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

    private var extractedText: String {
        model.attributeString.string
    }

    var body: some View {
        FocusableContainer(onInteraction: {
            Task { @MainActor in
                env.focusView = .popover
            }
        }) { contentView }
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
            let url = URL(fileURLWithPath: fileUrl)

            defaultAppForFile = bundleDisplayName(for: NSWorkspace.shared.urlForApplication(toOpen: url))

            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64
            {
                fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
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

    private var contentView: some View {
        VStack(alignment: .leading, spacing: Const.space12) {
            headerView
                .frame(height: 24)
            previewContent
                .clipShape(.rect(cornerRadius: Const.radius))
                .shadow(radius: 0.5)
                .frame(maxHeight: .infinity)
            footerView
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

    // MARK: - 子视图

    private var headerView: some View {
        HStack {
            Button {
                onClose?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
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
                BorderedButton(title: "编辑", action: openEditWindow)
            }

            if isSingleFile,
               let fileUrl = model.cachedFilePaths?.first,
               let defaultApp = defaultAppForFile
            {
                BorderedButton(title: "通过 \(defaultApp) 打开") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: fileUrl))
                }
            }
        }
    }

    private var shouldShowStatistics: Bool {
        if model.type == .link, enableLinkPreview, model.isLink {
            return false
        }
        return model.pasteboardType.isText()
    }

    private var textStatistics: TextStatistics {
        cachedTextStatistics ?? TextStatistics(from: model.attributeString.string)
    }

    private var footerView: some View {
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
                    BorderedButton(title: "在访达中显示", action: openInFinder)
                }
            }

            if model.type == .link,
               enableLinkPreview,
               let browserName = defaultBrowserName
            {
                BorderedButton(
                    title: "使用 \(browserName) 打开",
                    action: openInBrowser
                )
            }
        }
    }

    // MARK: - Actions

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

    private func openEditWindow() {
        EditWindowController.shared.openWindow(with: model)
    }

    // MARK: - Preview Content

    @ViewBuilder
    private var previewContent: some View {
        switch model.type {
        case .link:
            linkPreview
        case .color:
            colorPreview
        case .string:
            textPreview
        case .rich:
            richTextPreview
        case .image:
            imagePreview
        case .file:
            filePreview
        case .none:
            emptyPreview
        }
    }

    @ViewBuilder
    private var linkPreview: some View {
        if enableLinkPreview, model.isLink,
           let url = model.attributeString.string.asCompleteURL()
        {
            if #available(macOS 26.0, *) {
                WebContentView(url: url)
            } else {
                UIWebView(url: url)
            }
        } else {
            textPreview
        }
    }

    @ViewBuilder
    private var colorPreview: some View {
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
            .background(Color(nsColor: NSColor(hex: extractedText)))
        }
    }

    @ViewBuilder
    private var textPreview: some View {
        if model.length > Const.maxTextSize {
            LargeTextView(model: model)
                .frame(
                    width: Const.maxPreviewWidth - 32,
                    height: Const.maxContentHeight
                )
        } else {
            ZStack {
                Color(nsColor: .controlBackgroundColor)
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

    @ViewBuilder
    private var richTextPreview: some View {
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
                    richTextContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Const.space8)
                }
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: Const.maxPreviewWidth, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var richTextContent: some View {
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

    private var imagePreview: some View {
        ZStack {
            CheckerboardBackground()
            LiveTextImageView(imageData: model.data)
                .frame(
                    maxWidth: Const.maxPreviewWidth - Const.space12 * 2,
                    maxHeight: Const.maxContentHeight
                )
        }
    }

    private var filePreview: some View {
        Group {
            if let paths = model.cachedFilePaths, paths.count == 1, let firstPath = paths.first {
                QuickLookPreview(
                    url: URL(fileURLWithPath: firstPath),
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

    private var emptyPreview: some View {
        Text("无预览内容")
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
    let data = "https://www.apple.com.cn"
        .data(
            using: .utf8
        )!

    PreviewPopoverView(
        model: PasteboardModel(
            pasteboardType: .string,
            data: data,
            showData: data,
            timestamp: Int64(Date().timeIntervalSince1970),
            appPath: "/Applications/WeChat.app",
            appName: "微信",
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
