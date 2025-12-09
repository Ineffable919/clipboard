//
//  PreviewPopoverView.swift
//  Clipboard
//
//  Created by crown on 2025/10/20.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct PreviewPopoverView: View {
    static let defaultWidth: CGFloat = 400.0
    static let defaultHeight: CGFloat = 220.0

    let model: PasteboardModel

    @Environment(AppEnvironment.self) private var env
    @AppStorage(PrefKey.enableLinkPreview.rawValue)
    private var enableLinkPreview: Bool = PasteUserDefaults.enableLinkPreview

    var body: some View {
        FocusableContainer(onInteraction: {
            env.focusView = .popover
        }) {
            contentView
        }
        .onDisappear {
            env.focusView = .history
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: Const.space12) {
            HStack {
                if let appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }

                Text(model.appName)
                    .font(.body)

                Spacer()

                Text(model.type.string)
                    .font(.body)
            }

            previewContent
                .cornerRadius(Const.radius)
                .shadow(radius: 0.5)

            HStack {
                Text(model.introString())
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.head)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Const.space4)
                    .frame(
                        maxWidth: Const.maxPreviewWidth - 128,
                        alignment: .topLeading
                    )

                Spacer()

                if model.type == .file, model.fileSize() == 1 {
                    BorderedButton(title: "在访达中显示") {
                        withAnimation {
                            openInFinder()
                        }
                    }
                }

                if model.url != nil,
                   enableLinkPreview,
                   let browserName = getDefaultBrowserName()
                {
                    BorderedButton(title: "使用 \(browserName) 打开") {
                        withAnimation {
                            openInBrowser()
                        }
                    }
                }
            }
        }
        .padding(Const.space12)
        .frame(
            minWidth: Const.minPreviewWidth,
            maxWidth: Const.maxPreviewWidth,
            minHeight: Const.minPreviewHeight,
            maxHeight: Const.maxPreviewHeight,
        )
    }

    private func openInFinder() {
        if let filePath = String(data: model.data, encoding: .utf8) {
            NSWorkspace.shared.selectFile(
                filePath,
                inFileViewerRootedAtPath: "",
            )
        }
    }

    func getDefaultBrowserName() -> String? {
        if let appURL = NSWorkspace.shared.urlForApplication(toOpen: .html),
           let bundle = Bundle(url: appURL)
        {
            return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName")
                as? String ?? bundle.object(
                    forInfoDictionaryKey: "CFBundleName",
                ) as? String
        }
        return nil
    }

    private func openInBrowser() {
        if let url = model.url {
            NSWorkspace.shared.open(url)
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch model.type {
        case .link:
            if enableLinkPreview {
                if #available(macOS 26.0, *) {
                    WebContentView(url: model.url!)
                } else {
                    UIWebView(url: model.url!)
                }
            } else {
                textPreview
            }
        case .color:
            CSSView(model: model)
        case .string:
            textPreview
        case .rich:
            richTextPreview
        case .image:
            imagePreview
        case .file:
            filePreview
        case .none:
            Text("无预览内容")
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(
                    width: PreviewPopoverView.defaultWidth,
                    height: PreviewPopoverView.defaultHeight,
                    alignment: .center,
                )
        }
    }

    @ViewBuilder
    private var textPreview: some View {
        if model.length > Const.maxTextSize {
            LargeTextView(model: model)
                .frame(
                    width: Const.maxPreviewWidth - 32,
                    height: Const.maxContentHeight,
                )
        } else {
            ZStack {
                Color(nsColor: .controlBackgroundColor)
                ScrollView(.vertical, showsIndicators: true) {
                    Text(String(data: model.data, encoding: .utf8) ?? "")
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Const.space8)
                }
                .scrollContentBackground(.hidden)
            }
            .frame(
                maxWidth: Const.maxPreviewWidth,
                alignment: .topLeading,
            )
        }
    }

    @ViewBuilder
    private var richTextPreview: some View {
        if model.length > Const.maxRichTextSize {
            LargeTextView(model: model)
                .frame(
                    width: Const.maxPreviewWidth - 32,
                    height: Const.maxContentHeight,
                )
        } else {
            ZStack {
                model.backgroundColor
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading) {
                        if model.hasBgColor {
                            Text(
                                AttributedString(
                                    NSAttributedString(
                                        with: model.data,
                                        type: model.pasteboardType,
                                    )!,
                                ),
                            )
                            .textSelection(.enabled)
                        } else {
                            Text(model.attributeString.string)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Const.space8)
                }
                .scrollContentBackground(.hidden)
            }
            .frame(
                maxWidth: Const.maxPreviewWidth,
                alignment: .topLeading,
            )
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let image = NSImage(data: model.data) {
            ZStack {
                CheckerboardBackground()
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        maxWidth: Const.maxPreviewWidth,
                        maxHeight: Const.maxPreviewWidth,
                    )
            }
        } else {
            Image(systemName: "photo")
                .resizable()
                .font(.largeTitle)
                .foregroundColor(Color.accentColor.opacity(0.8))
                .frame(width: 144, height: 144, alignment: .center)
        }
    }

    @ViewBuilder
    private var filePreview: some View {
        VStack(alignment: .leading, spacing: Const.space8) {
            if let filePaths = String(data: model.data, encoding: .utf8) {
                let paths = filePaths.split(separator: "\n")
                    .map {
                        String($0).trimmingCharacters(
                            in: .whitespacesAndNewlines,
                        )
                    }
                    .filter { !$0.isEmpty }
                if paths.count == 1 {
                    QuickLookPreview(
                        url: URL(fileURLWithPath: paths.first!),
                        maxWidth: Const.maxPreviewWidth - 32,
                        maxHeight: Const.maxContentHeight,
                    )
                } else {
                    Image(systemName: "folder")
                        .resizable()
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                        .frame(width: 144, height: 144, alignment: .center)
                }
            }
        }
        .frame(
            width: Const.maxPreviewWidth - 32,
            height: Const.maxContentHeight
        )
    }

    private var appIcon: NSImage? {
        guard !model.appPath.isEmpty else { return nil }
        return NSWorkspace.shared.icon(forFile: model.appPath)
    }
}

// MARK: - BorderedButton with Hover Effect

struct BorderedButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var scheme

    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.system(size: Const.space12, weight: .light))
                .foregroundStyle(scheme == .dark ? .white : .black)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, Const.space8)
        .padding(.vertical, Const.space4)
        .background(
            RoundedRectangle(cornerRadius: Const.radius)
                .fill(isHovered ? .gray.opacity(0.1) : Color.clear),
        )
        .overlay(
            RoundedRectangle(cornerRadius: Const.radius)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1),
        )
        .onHover { hovering in
            isHovered = hovering
        }
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
            using: .utf8,
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
        ),
    )
    .frame(width: 800, height: 600)
}
