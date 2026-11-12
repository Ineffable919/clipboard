//
//  ClipPreviewPopover.swift
//  Clipboard
//
//  预览 Popover：NSPopover 子类，负责键盘事件拦截与尺寸计算
//

import AppKit
import Carbon

// MARK: - ClipPreviewPopover

final class ClipPreviewPopover: NSPopover {
    var onContentInteraction: (() -> Void)?
    var onPinToChip: ((PasteboardModel, Int) -> Void)?
    var onUnpin: ((PasteboardModel) -> Void)?
    var onCreateChip: ((PasteboardModel) -> Void)?
    var onDidClose: (() -> Void)?

    private let previewVC = ClipPreviewController()
    private nonisolated(unsafe) var keyMonitor: Any?

    // MARK: - Init

    override init() {
        super.init()
        behavior = .transient
        animates = true
        contentViewController = previewVC

        _ = previewVC.view

        installKeyMonitor()
        // delegate 由宿主控制器占用，关闭完成改用通知回收
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidClose),
            name: NSPopover.didCloseNotification,
            object: self
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    isolated deinit {
        let monitor = keyMonitor
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Public API

    func configure(with model: PasteboardModel, maxHeight: CGFloat = Const.maxPreviewHeight) {
        let size = previewVC.configure(with: model, maxHeight: maxHeight)
        // 弹窗关闭后复用时，新尺寸可能需要重挂载控制器才会生效
        // 弹窗显示期间直接更新尺寸，保留当前窗口供切卡使用
        if !isShown, contentSize != size {
            contentViewController = nil
            contentViewController = previewVC
        }
        contentSize = size

        previewVC.onContentInteraction = { [weak self] in
            self?.onContentInteraction?()
        }
        previewVC.onDismiss = { [weak self] in
            self?.close()
        }
        previewVC.onPinToChip = { [weak self] model, chipId in
            self?.onPinToChip?(model, chipId)
        }
        previewVC.onUnpin = { [weak self] model in
            self?.onUnpin?(model)
        }
        previewVC.onCreateChip = { [weak self] model in
            self?.onCreateChip?(model)
        }
    }

    func retarget(
        to model: PasteboardModel,
        relativeTo rect: NSRect,
        of anchor: NSView,
        preferredEdge: NSRectEdge,
        maxHeight: CGFloat
    ) {
        let wasAnimated = animates
        animates = false
        defer { animates = wasAnimated }

        configure(with: model, maxHeight: maxHeight)
        show(relativeTo: rect, of: anchor, preferredEdge: preferredEdge)
    }

    func refreshHeader() {
        previewVC.refreshHeader()
    }

    private func cleanup() {
        previewVC.cleanup()
        previewVC.onContentInteraction = nil
        previewVC.onDismiss = nil
        previewVC.onPinToChip = nil
        previewVC.onUnpin = nil
        previewVC.onCreateChip = nil
        onContentInteraction = nil
        onPinToChip = nil
        onUnpin = nil
        onCreateChip = nil
    }

    @objc private func handleDidClose(_: Notification) {
        cleanup()
        onDidClose?()
    }

    // MARK: - Size Calculation

    /// header(24) + space8 + space8 + footer(24) + inset*2(12+12)
    static let chrome: CGFloat = 24 + Const.space8 + Const.space8 + 24 + Const.space12 * 2

    /// 根据 model 类型计算 Popover 的最佳尺寸，maxHeight 由调用侧传入可用屏幕高度
    static func fitSize(for model: PasteboardModel, maxHeight: CGFloat = Const.maxPreviewHeight) -> NSSize {
        let cap = min(Const.maxPreviewHeight, maxHeight)
        let contentMaxH = max(cap - chrome, 0)
        let measuredText = measuredTextIfNeeded(for: model)

        let width = clampedWidth(
            for: model,
            contentMaxH: contentMaxH,
            measuredText: measuredText
        )
        let contentH = ClipPreviewContentView.preferredContentHeight(
            for: model,
            width: width,
            maxImageH: contentMaxH,
            measuredText: measuredText
        )
        let totalH = chrome + contentH
        let clampedH = min(max(totalH, Const.minPreviewHeight), cap)
        return NSSize(width: width, height: clampedH)
    }

    // MARK: - Width Calculation

    private static func clampedWidth(
        for model: PasteboardModel,
        contentMaxH: CGFloat = Const.maxTextheight,
        measuredText: NSAttributedString?
    ) -> CGFloat {
        switch model.type {
        case .color:
            return 400
        case .file, .link:
            return Const.maxPreviewWidth
        case .image:
            guard let size = model.cachedImageSize, size.width > 0 else {
                return Const.maxPreviewWidth
            }
            let scale = min(
                Const.maxPreviewWidth / size.width,
                contentMaxH / size.height,
                1.0
            )
            let displayW = ceil(size.width * scale) + Const.space12 * 2
            return min(max(displayW, Const.minPreviewWidth), Const.maxPreviewWidth)
        case .string, .rich:
            let textWidth = estimatedTextWidth(for: model, measuredText: measuredText)
            return min(
                max(textWidth, Const.minPreviewWidth),
                Const.maxTextWidth
            )
        case .none:
            return Const.minPreviewWidth
        }
    }

    private static func estimatedTextWidth(
        for model: PasteboardModel,
        measuredText: NSAttributedString?
    ) -> CGFloat {
        if model.length > Const.maxTextSize {
            return Const.maxTextWidth
        }

        let attributed = measuredText ?? ClipPreviewContentView.measuringAttributedString(for: model)
        guard attributed.length > 0 else { return Const.minPreviewWidth }

        let rect = attributed.boundingRect(
            with: NSSize(width: Const.maxTextWidth, height: Const.maxTextheight),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        return min(ceil(rect.width) + 32, Const.maxTextWidth)
    }

    private static func measuredTextIfNeeded(for model: PasteboardModel) -> NSAttributedString? {
        guard model.length <= Const.maxTextSize else { return nil }

        switch model.type {
        case .string, .rich:
            return ClipPreviewContentView.measuringAttributedString(for: model)
        case .link where !PasteUserDefaults.enableLinkPreview || !model.isLink:
            return ClipPreviewContentView.measuringAttributedString(for: model)
        default:
            return nil
        }
    }

    // MARK: - Key Monitor

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // 方向键交给宿主按焦点处理，焦点在预览内时留给网页、文本等内容
            guard let self, isShown, Int(event.keyCode) == kVK_Escape else { return event }
            close()
            return nil
        }
    }
}
