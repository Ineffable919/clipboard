//
//  ClipPreviewContentView.swift
//  Clipboard
//
//  根据剪贴板内容类型切换对应预览视图。
//

import AppKit
import SnapKit

final class ClipPreviewContentView: NSView {
    private var currentContentView: NSView?
    private var mouseMonitor: Any?

    var onMouseDown: (() -> Void)?

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

    /// 根据 model 类型计算内容区域的理想高度，maxImageH 由调用侧传入屏幕可用内容高度
    static func preferredContentHeight(
        for model: PasteboardModel,
        width: CGFloat,
        maxImageH: CGFloat = Const.maxTextheight,
        measuredText: NSAttributedString? = nil
    ) -> CGFloat {
        switch model.type {
        case .color:
            return 270
        case .file:
            return Const.maxContentHeight
        case .link:
            if PasteUserDefaults.enableLinkPreview, model.isLink {
                return Const.maxContentHeight
            }
            return textContentHeight(for: model, width: width, measuredText: measuredText)
        case .image:
            return imageContentHeight(for: model, maxH: maxImageH)
        case .string, .rich:
            return textContentHeight(for: model, width: width, measuredText: measuredText)
        case .none:
            return 270
        }
    }

    static func measuringAttributedString(for model: PasteboardModel) -> NSAttributedString {
        if model.usesMarkdownPreview {
            return MarkdownAttributedRenderer.renderSync(model.markdownSource)
        }
        if model.type == .rich {
            return NSAttributedString(with: model.data, type: model.pasteboardType)
                ?? model.attributeString
        }
        return model.attributeString
    }

    var isMarkdownContent: Bool {
        currentContentView is PreviewMarkdownView
    }

    func toggleMarkdownMode() -> Bool {
        guard let markdownView = currentContentView as? PreviewMarkdownView else {
            return true
        }
        return markdownView.toggleRendered()
    }

    private static func textContentHeight(
        for model: PasteboardModel,
        width: CGFloat,
        measuredText: NSAttributedString?
    ) -> CGFloat {
        if model.length > Const.maxTextSize {
            return Const.maxTextheight
        }

        let inset: CGFloat = Const.space8 * 2
        let textWidth = width - inset * 2
        guard textWidth > 0 else { return 240.0 }

        let attributed = measuredText ?? Self.measuringAttributedString(for: model)
        let boundingRect = attributed.boundingRect(
            with: NSSize(width: textWidth, height: Const.maxTextheight),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        let measured = ceil(boundingRect.height) + inset * 2
        return min(max(measured, 240.0), Const.maxTextheight)
    }

    private static func imageContentHeight(for model: PasteboardModel, maxH: CGFloat) -> CGFloat {
        guard let size = model.cachedImageSize, size.width > 0, size.height > 0 else {
            return 270.0
        }
        let availableW = Const.maxPreviewWidth - Const.space12 * 2
        let scale = min(availableW / size.width, maxH / size.height, 1.0)
        return ceil(size.height * scale)
    }

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
               let url = model.attributeString.string.asCompleteURL() {
                PreviewWebView(url: url)
            } else {
                PreviewTextContentView(model: model)
            }
        case .string, .rich:
            if model.usesMarkdownPreview {
                PreviewMarkdownView(model: model)
            } else {
                PreviewTextContentView(model: model)
            }
        case .none:
            PreviewEmptyView()
        }
    }

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
