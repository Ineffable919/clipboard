//
//  ClipPreviewContentView.swift
//  Clipboard
//
//  预览内容容器：根据 model 类型切换子视图，包含所有内容子视图实现
//

import AppKit
import Quartz
import SnapKit
import VisionKit
import WebKit

private protocol PreviewResettable {
    func resetPreview()
}

// MARK: - ClipPreviewContentView

final class ClipPreviewContentView: NSView {
    // MARK: - State

    private var currentContentView: NSView?
    private var mouseMonitor: Any?

    // MARK: - Callbacks

    var onMouseDown: (() -> Void)?

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = Const.settingsRadius
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Appearance

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installMouseMonitor()
        } else {
            removeMouseMonitor()
        }
    }

    // MARK: - Public API

    func configure(with model: PasteboardModel, maxContentH: CGFloat = Const.maxTextheight) {
        reset()

        let contentView = makeContentView(for: model, maxContentH: maxContentH)
        addSubview(contentView)
        contentView.snp.makeConstraints { $0.edges.equalToSuperview() }
        currentContentView = contentView
    }

    func reset() {
        (currentContentView as? PreviewResettable)?.resetPreview()
        currentContentView?.removeFromSuperview()
        currentContentView = nil
    }

    // MARK: - Size Hint

    /// 根据 model 类型计算内容区域的理想高度，maxImageH 由调用侧传入屏幕可用内容高度
    static func preferredContentHeight(for model: PasteboardModel, width: CGFloat, maxImageH: CGFloat = Const.maxTextheight) -> CGFloat {
        switch model.type {
        case .color:
            return 270
        case .file:
            return Const.maxContentHeight
        case .link:
            if PasteUserDefaults.enableLinkPreview, model.isLink {
                return Const.maxContentHeight
            }
            return textContentHeight(for: model, width: width)
        case .image:
            return imageContentHeight(for: model, maxH: maxImageH)
        case .string, .rich:
            return textContentHeight(for: model, width: width)
        case .none:
            return 270
        }
    }

    // MARK: - Private Size Helpers

    private static func textContentHeight(for model: PasteboardModel, width: CGFloat) -> CGFloat {
        if model.length > Const.maxTextSize { return Const.maxTextheight }

        let inset: CGFloat = Const.space8 * 2
        let textWidth = width - inset * 2
        guard textWidth > 0 else { return 240.0 }

        let attributed = Self.measuringAttributedString(for: model)
        let boundingRect = attributed.boundingRect(
            with: NSSize(width: textWidth, height: Const.maxTextheight),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        let measured = ceil(boundingRect.height) + inset * 2
        return min(max(measured, 240.0), Const.maxTextheight)
    }

    static func measuringAttributedString(for model: PasteboardModel) -> NSAttributedString {
        if model.type == .rich {
            return NSAttributedString(with: model.data, type: model.pasteboardType)
                ?? model.attributeString
        }
        return model.attributeString
    }

    private static func imageContentHeight(for model: PasteboardModel, maxH: CGFloat) -> CGFloat {
        guard let size = model.cachedImageSize, size.width > 0, size.height > 0 else {
            return 270.0
        }
        let availableW = Const.maxPreviewWidth - Const.space12 * 2
        let scale = min(availableW / size.width, maxH / size.height, 1.0)
        return ceil(size.height * scale)
    }

    // MARK: - Factory

    private func makeContentView(for model: PasteboardModel, maxContentH: CGFloat) -> NSView {
        switch model.type {
        case .color:
            PreviewColorView(model: model)
        case .image:
            PreviewImageView(model: model, maxContentH: maxContentH)
        case .file:
            PreviewFileView(model: model)
        case .link:
            if PasteUserDefaults.enableLinkPreview, model.isLink,
               let url = model.attributeString.string.asCompleteURL()
            {
                PreviewWebView(url: url)
            } else {
                PreviewTextContentView(model: model)
            }
        case .string, .rich:
            PreviewTextContentView(model: model)
        case .none:
            PreviewEmptyView()
        }
    }

    // MARK: - Mouse Monitor

    private func installMouseMonitor() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let viewWindow = window else { return event }
            guard event.window === viewWindow else { return event }
            let locationInSelf = convert(event.locationInWindow, from: nil)
            if bounds.contains(locationInSelf) {
                onMouseDown?()
            }
            return event
        }
    }

    private func removeMouseMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
}

// MARK: - PreviewTextContentView

final class PreviewTextContentView: NSView {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()

    private let fixedBgColor: NSColor?

    init(model: PasteboardModel) {
        if model.type == .rich, model.hasBgColor, let bg = model.cachedBackgroundColor {
            fixedBgColor = bg
        } else {
            fixedBgColor = nil
        }

        super.init(frame: .zero)
        wantsLayer = true

        setupScrollView()
        setupTextView()

        if let bg = fixedBgColor {
            textView.backgroundColor = bg
            layer?.backgroundColor = bg.cgColor
        } else {
            textView.backgroundColor = .textBackgroundColor
        }

        scrollView.documentView = textView
        addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        applyContent(for: model)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if let bg = fixedBgColor {
            layer?.backgroundColor = bg.cgColor
        }
    }

    override func layout() {
        super.layout()
        let w = scrollView.contentSize.width
        guard w > 0 else { return }
        if textView.frame.width != w {
            textView.frame = NSRect(x: 0, y: 0, width: w, height: max(scrollView.contentSize.height, 1))
            textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
            textView.maxSize = NSSize(width: w, height: .greatestFiniteMagnitude)
            textView.textContainer?.containerSize = NSSize(width: w, height: .greatestFiniteMagnitude)
        }
    }

    // MARK: - Private Setup

    private func setupScrollView() {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
    }

    private func setupTextView() {
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: Const.space8, height: Const.space8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        textView.textContainer?.widthTracksTextView = true
        textView.layoutManager?.allowsNonContiguousLayout = true
    }

    // MARK: - Content

    private func applyContent(for model: PasteboardModel) {
        switch model.type {
        case .rich:
            applyRichContent(for: model)
        default:
            applyPlainContent(for: model)
        }
    }

    private func applyRichContent(for model: PasteboardModel) {
        let base = NSAttributedString(with: model.data, type: model.pasteboardType)
            ?? model.attributeString

        if model.hasBgColor {
            textView.textStorage?.setAttributedString(base)
        } else {
            let mutable = NSMutableAttributedString(attributedString: base)
            mutable.addAttribute(
                .foregroundColor,
                value: NSColor.labelColor,
                range: NSRange(location: 0, length: mutable.length)
            )
            textView.textStorage?.setAttributedString(mutable)
        }
    }

    private func applyPlainContent(for model: PasteboardModel) {
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .labelColor
        textView.string = String(data: model.data, encoding: .utf8)
            ?? model.attributeString.string
    }
}

// MARK: - PreviewColorView

final class PreviewColorView: NSView {
    init(model: PasteboardModel) {
        super.init(frame: .zero)
        wantsLayer = true

        let (bg, fg) = model.colors()
        layer?.backgroundColor = bg.cgColor

        let label = NSTextField(labelWithString: model.colorDisplayText)
        label.font = .systemFont(ofSize: NSFont.systemFontSize * 1.7, weight: .medium)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.textColor = fg

        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Const.space12)
            make.trailing.lessThanOrEqualToSuperview().offset(-Const.space12)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}

// MARK: - PreviewImageView

final class PreviewImageView: NSView, PreviewResettable {
    private let liveTextView: PreviewLiveTextView

    init(model: PasteboardModel, maxContentH: CGFloat = Const.maxTextheight) {
        liveTextView = PreviewLiveTextView(imageData: model.data)
        super.init(frame: .zero)
        wantsLayer = true

        let checker = CheckerboardView()
        addSubview(checker)
        checker.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(liveTextView)

        if let size = model.cachedImageSize, size.width > 0, size.height > 0 {
            let availableW = Const.maxPreviewWidth - Const.space12 * 2
            let scale = min(availableW / size.width, maxContentH / size.height, 1.0)
            let displayW = ceil(size.width * scale)
            let displayH = ceil(size.height * scale)
            liveTextView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.equalTo(displayW)
                make.height.equalTo(displayH)
                make.leading.greaterThanOrEqualToSuperview()
                make.trailing.lessThanOrEqualToSuperview()
                make.top.greaterThanOrEqualToSuperview()
                make.bottom.lessThanOrEqualToSuperview()
            }
        } else {
            liveTextView.snp.makeConstraints { $0.edges.equalToSuperview() }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func resetPreview() {
        liveTextView.resetPreview()
    }
}

// MARK: - PreviewFileView

final class PreviewFileView: NSView, PreviewResettable {
    private var previewContentView: (NSView & PreviewResettable)?

    init(model: PasteboardModel) {
        super.init(frame: .zero)
        wantsLayer = true

        if let paths = model.cachedFilePaths, !paths.isEmpty {
            if paths.count == 1, let first = paths.first {
                let qlView = PreviewQuickLookView(filePath: first)
                previewContentView = qlView
                addSubview(qlView)
                qlView.snp.makeConstraints { $0.edges.equalToSuperview() }
            } else {
                let multiView = PreviewMultiFileView(filePaths: paths)
                addSubview(multiView)
                multiView.snp.makeConstraints { $0.edges.equalToSuperview() }
            }
        } else {
            let iv = NSImageView()
            iv.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
            iv.contentTintColor = NSColor.controlAccentColor.withAlphaComponent(0.8)
            iv.imageScaling = .scaleProportionallyUpOrDown
            addSubview(iv)
            iv.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(80)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func resetPreview() {
        previewContentView?.resetPreview()
        previewContentView = nil
    }
}

// MARK: - PreviewQuickLookView

final class PreviewQuickLookView: NSView, PreviewResettable {
    private var qlView: QLPreviewView?

    init(filePath: String) {
        super.init(frame: .zero)
        wantsLayer = true

        let url = URL(fileURLWithPath: filePath)

        guard let preview = QLPreviewView(frame: .zero, style: .normal) else {
            showFallbackIcon(for: url)
            return
        }

        preview.autoresizingMask = [.width, .height]
        preview.previewItem = url as QLPreviewItem
        qlView = preview

        addSubview(preview)
        preview.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func resetPreview() {
        qlView?.previewItem = nil
        qlView?.removeFromSuperview()
        qlView = nil
    }

    private func showFallbackIcon(for url: URL) {
        let icon = NSWorkspace.shared.icon(forFile: url.path())
        let iv = NSImageView()
        iv.image = icon
        iv.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iv)
        iv.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(128)
        }
    }
}

// MARK: - PreviewMultiFileView

final class PreviewMultiFileView: NSView {
    init(filePaths: [String]) {
        super.init(frame: .zero)
        wantsLayer = true

        let paths = Array(filePaths.prefix(4))
        let thumbSize: CGFloat = 320

        for (index, path) in paths.enumerated().reversed() {
            let url = URL(fileURLWithPath: path)
            let icon = NSWorkspace.shared.icon(forFile: url.path())
            let iv = NSImageView()
            iv.image = icon
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.wantsLayer = true
            iv.layer?.cornerRadius = Const.radius
            iv.layer?.masksToBounds = true

            addSubview(iv)
            let xOffset = CGFloat(index) * 20
            let yOffset = CGFloat(index) * 10
            iv.snp.makeConstraints { make in
                make.width.height.equalTo(thumbSize)
                make.centerX.equalToSuperview().offset(xOffset - Const.space32)
                make.centerY.equalToSuperview().offset(-yOffset)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}

// MARK: - PreviewWebView

final class PreviewWebView: NSView, WKNavigationDelegate, PreviewResettable {
    private let webView: WKWebView
    private let loadingIndicator: NSProgressIndicator

    init(url: URL) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: config)
        loadingIndicator = NSProgressIndicator()
        super.init(frame: .zero)
        wantsLayer = true

        webView.navigationDelegate = self
        webView.alphaValue = 0

        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .regular

        addSubview(webView)
        addSubview(loadingIndicator)

        webView.snp.makeConstraints { $0.edges.equalToSuperview() }
        loadingIndicator.snp.makeConstraints { $0.center.equalToSuperview() }

        loadingIndicator.startAnimation(nil)
        webView.load(URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 10
        ))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func stopLoading() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
    }

    func resetPreview() {
        stopLoading()
    }

    // MARK: WKNavigationDelegate

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        finishLoading()
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
        finishLoading()
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
        finishLoading()
    }

    private func finishLoading() {
        loadingIndicator.stopAnimation(nil)
        loadingIndicator.isHidden = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            webView.animator().alphaValue = 1
        }
    }
}

// MARK: - PreviewEmptyView

final class PreviewEmptyView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        let label = NSTextField(labelWithString: String(localized: .noPreview))
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        addSubview(label)
        label.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}

// MARK: - PreviewLiveTextView

final class PreviewLiveTextView: NSView, ImageAnalysisOverlayViewDelegate, PreviewResettable {
    @MainActor private static var activeAnalysisTask: Task<Void, Never>?
    @MainActor private static var activeAnalysisGeneration = 0

    private let imageView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.imageAlignment = .alignCenter
        return iv
    }()

    private let overlayView = ImageAnalysisOverlayView()
    private var analysisTask: Task<Void, Never>?

    private static let analysisDelay: Duration = .milliseconds(400)

    private static let sharedAnalyzer: ImageAnalyzer? = {
        guard ImageAnalyzer.isSupported else { return nil }
        return ImageAnalyzer()
    }()

    init(imageData: Data) {
        super.init(frame: .zero)
        setupViews()
        loadImage(from: imageData)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit {
        analysisTask?.cancel()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            cancelAnalysis()
        } else {
            scheduleAnalysisIfNeeded()
        }
    }

    func resetPreview() {
        cancelAnalysis()
        overlayView.analysis = nil
        overlayView.trackingImageView = nil
        overlayView.delegate = nil
        imageView.image = nil
    }

    private func setupViews() {
        addSubview(imageView)
        overlayView.delegate = self
        overlayView.preferredInteractionTypes = .automatic
        addSubview(overlayView)

        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        overlayView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func loadImage(from data: Data) {
        if let image = NSImage(data: data) {
            imageView.image = image
            scheduleAnalysisIfNeeded()
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
            imageView.image = NSImage(
                systemSymbolName: "photo.badge.arrow.down",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(config)
            imageView.imageScaling = .scaleNone
            imageView.contentTintColor = .secondaryLabelColor
        }
    }

    private func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
    }

    private func scheduleAnalysisIfNeeded() {
        guard window != nil,
              imageView.image != nil,
              overlayView.analysis == nil,
              Self.sharedAnalyzer != nil
        else { return }

        analysisTask?.cancel()
        analysisTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.analysisDelay)
            } catch {
                return
            }

            guard let self,
                  !Task.isCancelled,
                  window != nil,
                  let image = imageView.image
            else { return }

            Self.activeAnalysisTask?.cancel()
            Self.activeAnalysisGeneration += 1
            let generation = Self.activeAnalysisGeneration
            Self.activeAnalysisTask = analysisTask
            await analyzeImage(image)
            if Self.activeAnalysisGeneration == generation {
                Self.activeAnalysisTask = nil
            }
        }
    }

    private func analyzeImage(_ image: NSImage) async {
        guard let analyzer = Self.sharedAnalyzer,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              !Task.isCancelled
        else { return }

        let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode])
        do {
            let analysis = try await analyzer.analyze(
                cgImage,
                orientation: .up,
                configuration: configuration
            )
            guard !Task.isCancelled, window != nil else { return }
            overlayView.analysis = analysis
            overlayView.trackingImageView = imageView
            overlayView.setContentsRectNeedsUpdate()
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            log.warn("Live Text analysis failed: \(error)")
        }
    }

    override func layout() {
        super.layout()
        overlayView.setContentsRectNeedsUpdate()
    }

    // MARK: ImageAnalysisOverlayViewDelegate

    func contentsRect(for _: ImageAnalysisOverlayView) -> CGRect {
        guard let image = imageView.image,
              bounds.width > 0, bounds.height > 0
        else { return CGRect(x: 0, y: 0, width: 1, height: 1) }

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        let viewSize = bounds.size
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        let renderedWidth: CGFloat
        let renderedHeight: CGFloat

        if imageAspect > viewAspect {
            renderedWidth = viewSize.width
            renderedHeight = viewSize.width / imageAspect
        } else {
            renderedHeight = viewSize.height
            renderedWidth = viewSize.height * imageAspect
        }

        return CGRect(
            x: (viewSize.width - renderedWidth) / 2 / viewSize.width,
            y: (viewSize.height - renderedHeight) / 2 / viewSize.height,
            width: renderedWidth / viewSize.width,
            height: renderedHeight / viewSize.height
        )
    }
}
