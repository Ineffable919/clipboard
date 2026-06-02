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

    private let previewVC = ClipPreviewController()
    private nonisolated(unsafe) var keyMonitor: Any?

    // MARK: - Init

    init(model: PasteboardModel, maxHeight: CGFloat = Const.maxPreviewHeight, onContentInteraction: (() -> Void)? = nil) {
        self.onContentInteraction = onContentInteraction
        super.init()
        behavior = .transient
        animates = true
        contentViewController = previewVC

        _ = previewVC.view

        configure(with: model, maxHeight: maxHeight)
        installKeyMonitor()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit {
        let monitor = keyMonitor
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    // MARK: - Public API

    func configure(with model: PasteboardModel, maxHeight: CGFloat = Const.maxPreviewHeight) {
        let size = previewVC.configure(with: model, maxHeight: maxHeight)
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

    func refreshHeader() {
        previewVC.refreshHeader()
    }

    func cleanup() {
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

    // MARK: - Size Calculation

    // header(24) + space8 + space8 + footer(24) + inset*2(12+12)
    static let chrome: CGFloat = 24 + Const.space8 + Const.space8 + 24 + Const.space12 * 2

    /// 根据 model 类型计算 Popover 的最佳尺寸，maxHeight 由调用侧传入可用屏幕高度
    static func fitSize(for model: PasteboardModel, maxHeight: CGFloat = Const.maxPreviewHeight) -> NSSize {
        let cap = min(Const.maxPreviewHeight, maxHeight)
        let contentMaxH = max(cap - chrome, 0)

        let width = clampedWidth(for: model, contentMaxH: contentMaxH)
        let contentH = ClipPreviewContentView.preferredContentHeight(
            for: model,
            width: width,
            maxImageH: contentMaxH
        )
        let totalH = chrome + contentH
        let clampedH = min(max(totalH, Const.minPreviewHeight), cap)
        return NSSize(width: width, height: clampedH)
    }

    // MARK: - Width Calculation

    private static func clampedWidth(for model: PasteboardModel, contentMaxH: CGFloat = Const.maxTextheight) -> CGFloat {
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
            let textWidth = estimatedTextWidth(for: model)
            return min(
                max(textWidth, Const.minPreviewWidth),
                Const.maxTextWidth
            )
        case .none:
            return Const.minPreviewWidth
        }
    }

    private static func estimatedTextWidth(for model: PasteboardModel) -> CGFloat {
        if model.length > Const.maxTextSize { return Const.maxTextWidth }

        let attributed = ClipPreviewContentView.measuringAttributedString(for: model)
        guard attributed.length > 0 else { return Const.minPreviewWidth }

        let rect = attributed.boundingRect(
            with: NSSize(width: Const.maxTextWidth, height: Const.maxTextheight),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        return min(ceil(rect.width) + 32, Const.maxTextWidth)
    }

    // MARK: - Key Monitor

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, isShown else { return event }
            switch Int(event.keyCode) {
            case kVK_Escape:
                close()
                return nil
            case kVK_LeftArrow, kVK_RightArrow:
                close()
                return event
            default:
                return event
            }
        }
    }
}
