//
//  PreviewMarkdownView.swift
//  Clipboard
//
//  markdown 预览内容视图：默认渲染，可切换查看原文
//

import AppKit
import SnapKit
import WebKit

final class PreviewMarkdownView: NSView, WKNavigationDelegate, WKUIDelegate {
    private let webView: WKWebView
    private let sourceScrollView = NSScrollView()
    private let sourceTextView = NSTextView()
    private let model: PasteboardModel
    private let sourceBackgroundColor: NSColor?

    /// 是否处于渲染态
    private(set) var isRendered = true

    init(model: PasteboardModel) {
        self.model = model
        if model.type == .rich, let bg = model.safeBgColor {
            sourceBackgroundColor = bg
        } else {
            sourceBackgroundColor = nil
        }
        let configuration = Self.makeWebConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: .zero)
        wantsLayer = true

        setupWebView()
        setupSourceScrollView()
        setupSourceTextView()
        setupLayout()

        applyContent()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func layout() {
        super.layout()
        let w = sourceScrollView.contentSize.width
        guard w > 0 else { return }
        if sourceTextView.frame.width != w {
            sourceTextView.frame = NSRect(x: 0, y: 0, width: w, height: max(sourceScrollView.contentSize.height, 1))
            sourceTextView.minSize = NSSize(width: 0, height: sourceScrollView.contentSize.height)
            sourceTextView.maxSize = NSSize(width: w, height: .greatestFiniteMagnitude)
            sourceTextView.textContainer?.containerSize = NSSize(width: w, height: .greatestFiniteMagnitude)
        }
    }

    // MARK: - Public API

    @discardableResult
    func toggleRendered() -> Bool {
        isRendered.toggle()
        applyContent()
        return isRendered
    }

    // MARK: - Private Setup

    private static func makeWebConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.suppressesIncrementalRendering = false
        return configuration
    }

    private func setupWebView() {
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsMagnification = false
    }

    private func setupSourceScrollView() {
        sourceScrollView.hasVerticalScroller = true
        sourceScrollView.hasHorizontalScroller = false
        sourceScrollView.autohidesScrollers = true
        sourceScrollView.scrollerStyle = .overlay
        sourceScrollView.borderType = .noBorder
        sourceScrollView.drawsBackground = false
        sourceScrollView.isHidden = true
    }

    private func setupSourceTextView() {
        sourceTextView.isEditable = false
        sourceTextView.isSelectable = true
        sourceTextView.drawsBackground = true
        sourceTextView.backgroundColor = sourceBackgroundColor ?? .textBackgroundColor
        sourceTextView.isAutomaticLinkDetectionEnabled = false
        sourceTextView.textContainerInset = NSSize(width: Const.space8, height: Const.space8)
        sourceTextView.isVerticallyResizable = true
        sourceTextView.isHorizontallyResizable = false
        sourceTextView.autoresizingMask = .width
        sourceTextView.textContainer?.widthTracksTextView = true
        sourceTextView.layoutManager?.allowsNonContiguousLayout = true
        sourceScrollView.documentView = sourceTextView
    }

    private func setupLayout() {
        addSubview(webView)
        addSubview(sourceScrollView)

        webView.snp.makeConstraints { $0.edges.equalToSuperview() }
        sourceScrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    // MARK: - Content

    private func applyContent() {
        let source = model.markdownSource
        webView.isHidden = !isRendered
        sourceScrollView.isHidden = isRendered

        if isRendered {
            webView.loadHTMLString(
                MarkdownHTMLRenderer.htmlDocument(for: source),
                baseURL: URL(fileURLWithPath: "/")
            )
        } else {
            applyOriginalContent(source: source)
        }
    }

    private func applyOriginalContent(source: String) {
        switch model.type {
        case .rich:
            applyOriginalRichContent()
        default:
            applyMarkdownSourceContent(source)
        }
    }

    private func applyOriginalRichContent() {
        let base = NSAttributedString(with: model.data, type: model.pasteboardType)
            ?? model.attributeString

        if model.hasBgColor {
            sourceTextView.textStorage?.setAttributedString(base)
        } else {
            let mutable = NSMutableAttributedString(attributedString: base)
            mutable.addAttribute(
                .foregroundColor,
                value: NSColor.labelColor,
                range: NSRange(location: 0, length: mutable.length)
            )
            sourceTextView.textStorage?.setAttributedString(mutable)
        }
    }

    private func applyMarkdownSourceContent(_ source: String) {
        sourceTextView.textStorage?.setAttributedString(NSAttributedString(
            string: source,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .regular),
                .foregroundColor: NSColor.labelColor,
            ]
        ))
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if let sourceBackgroundColor {
            sourceTextView.backgroundColor = sourceBackgroundColor
            layer?.backgroundColor = sourceBackgroundColor.cgColor
        } else {
            sourceTextView.backgroundColor = .textBackgroundColor
            layer?.backgroundColor = nil
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(
        _: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.navigationType == .linkActivated else {
            decisionHandler(.allow)
            return
        }

        guard let url = navigationAction.request.url,
              ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "")
        else {
            decisionHandler(.cancel)
            return
        }

        NSWorkspace.shared.open(url)
        decisionHandler(.cancel)
    }

    // MARK: - WKUIDelegate

    func webView(
        _: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures _: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url,
              ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "")
        else {
            return nil
        }

        NSWorkspace.shared.open(url)
        return nil
    }
}
