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

    private let vm = ClipboardViewModel.shard

    var body: some View {
        FocusableContainer(onInteraction: {
            vm.focusView = .popover
        }) {
            contentView
        }
        .onDisappear {
            vm.focusView = .history
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }

                Text(model.appName)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                Text(model.type.string)
                    .font(.body)
                    .padding(.horizontal, Const.space)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(Const.radius)
            }

            previewContent
                .cornerRadius(Const.radius)
                .shadow(radius: 0.5)

            HStack {
                Text(model.introString())
                    .font(.body)
                    .foregroundColor(.secondary)
                    .truncationMode(.head)
                    .frame(
                        maxWidth: 500,
                        alignment: .bottomLeading,
                    )

                Spacer()

                if model.type == .file, model.fileSize() == 1 {
                    BorderedButton(title: "在 Finder 中显示") {
                        withAnimation {
                            openInFinder()
                        }
                    }
                }

                if model.url != nil,
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
        .padding(12)
        .frame(
            minWidth: 400,
            maxWidth: 800,
            minHeight: 300,
            maxHeight: 600,
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
        case .string:
            if model.url != nil {
                if #available(macOS 26.0, *) {
                    WebContentView(url: model.url!)
                } else {
                    EarlierWebView(url: model.url!)
                }
            } else {
                textPreview
            }
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
            Text("文本超过最大展示限制\(Const.maxTextSize)字符")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(
                    width: PreviewPopoverView.defaultWidth,
                    height: PreviewPopoverView.defaultHeight,
                    alignment: .center,
                )
                .background(Color(nsColor: .controlBackgroundColor))
        } else {
            ZStack {
                Color(nsColor: .controlBackgroundColor)
                ScrollView(.vertical, showsIndicators: true) {
                    Text(String(data: model.data, encoding: .utf8) ?? "")
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Const.space)
                }
                .scrollContentBackground(.hidden)
            }
            .frame(
                maxWidth: Const.maxPreviewSize,
                alignment: .topLeading,
            )
        }
    }

    @ViewBuilder
    private var richTextPreview: some View {
        if model.length > Const.maxRichTextSize {
            Text("文本超过最大展示限制\(Const.maxRichTextSize)字符")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(
                    width: PreviewPopoverView.defaultWidth,
                    height: PreviewPopoverView.defaultHeight,
                    alignment: .center,
                )
                .background(Color(nsColor: .controlBackgroundColor))
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
                    .padding(Const.space)
                }
                .scrollContentBackground(.hidden)
            }
            .frame(
                maxWidth: Const.maxPreviewSize,
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
                        maxWidth: Const.maxPreviewSize,
                        maxHeight: Const.maxPreviewSize,
                    )
            }
        } else {
            Image(systemName: "photo")
                .resizable()
                .font(.largeTitle)
                .foregroundColor(Color.accentColor.opacity(0.8))
                .frame(width: 128, height: 128, alignment: .center)
        }
    }

    @ViewBuilder
    private var filePreview: some View {
        VStack(alignment: .leading, spacing: Const.space) {
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
                        maxWidth: Const.maxPreviewSize - 32,
                        maxHeight: Const.maxPreviewHeight,
                    )
                } else {
                    Image(systemName: "doc.text")
                        .resizable()
                        .symbolRenderingMode(.multicolor)
                        .foregroundColor(Color.accentColor.opacity(0.8))
                        .frame(width: 128, height: 144, alignment: .center)
                }
            }
        }
        .frame(width: Const.maxPreviewSize - 32, height: Const.maxPreviewHeight)
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
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(scheme == .dark ? .white : .black)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
        if hitView != nil {
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
