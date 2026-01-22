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

    @Environment(AppEnvironment.self) private var env
    @AppStorage(PrefKey.enableLinkPreview.rawValue)
    private var enableLinkPreview: Bool = PasteUserDefaults.enableLinkPreview

    private var appIcon: NSImage? {
        guard !model.appPath.isEmpty else { return nil }
        return NSWorkspace.shared.icon(forFile: model.appPath)
    }

    private var cachedDataString: String? {
        if let attr = NSAttributedString(
            with: model.data,
            type: model.pasteboardType
        ) {
            attr.string
        } else {
            String(data: model.data, encoding: .utf8)
        }
    }

    private var cachedDefaultBrowserName: String? {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: .html),
              let bundle = Bundle(url: appURL)
        else { return nil }
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName")
            as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    }

    private var cachedDefaultAppForFile: String? {
        guard model.type == .file,
              model.fileSize() == 1,
              let fileUrl = model.cachedFilePaths?.first
        else { return nil }
        let url = URL(fileURLWithPath: fileUrl)
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: url),
              let bundle = Bundle(url: appURL)
        else { return nil }
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName")
            as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    }

    var body: some View {
        FocusableContainer(onInteraction: {
            Task { @MainActor in
                env.focusView = .popover
            }
        }) { contentView }
            .onDisappear {
                if env.focusView != .search {
                    env.focusView = .history
                }
            }
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

            if let fileUrl = model.cachedFilePaths?.first,
               let defaultApp = cachedDefaultAppForFile
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
        let fullText: String =
            if let attr = NSAttributedString(
                with: model.data,
                type: model.pasteboardType
            ) {
                attr.string
            } else {
                String(data: model.data, encoding: .utf8) ?? ""
            }
        return TextStatistics(from: fullText)
    }

    private var footerView: some View {
        HStack {
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

            if model.type == .file, model.fileSize() == 1 {
                BorderedButton(title: "在访达中显示", action: openInFinder)
            }

            if model.type == .link,
               enableLinkPreview,
               let browserName = cachedDefaultBrowserName
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
        guard let filePath = cachedDataString else { return }
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
        if let hex = cachedDataString {
            VStack(alignment: .center) {
                Text(hex)
                    .font(.title2)
                    .foregroundStyle(textColor)
            }
            .frame(
                maxWidth: Const.maxPreviewWidth,
                maxHeight: Const.maxPreviewHeight,
                alignment: .center
            )
            .background(Color(nsColor: NSColor(hex: hex)))
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
                    Text(cachedDataString ?? "")
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

    @ViewBuilder
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

    @ViewBuilder
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
    let content: Content

    init(
        onInteraction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onInteraction = onInteraction
        self.content = content()
    }

    func makeNSView(context _: Context) -> NSHostingView<Content> {
        let hostingView = InterceptingHostingView(
            rootView: content,
            onInteraction: onInteraction
        )
        return hostingView
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context _: Context) {
        nsView.rootView = content
    }
}

class InterceptingHostingView<Content: View>: NSHostingView<Content> {
    let onInteraction: () -> Void

    init(rootView: Content, onInteraction: @escaping () -> Void) {
        self.onInteraction = onInteraction
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
}

// MARK: - Preview

#Preview {
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
        )
    )
    .frame(width: 800, height: 600)
}
