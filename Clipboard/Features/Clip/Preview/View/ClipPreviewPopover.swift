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

    private let previewVC = ClipPreviewController()
    private nonisolated(unsafe) var keyMonitor: Any?

    // MARK: - Init

    init(model: PasteboardModel, onContentInteraction: (() -> Void)? = nil) {
        self.onContentInteraction = onContentInteraction
        super.init()
        behavior = .transient
        animates = true
        contentViewController = previewVC

        _ = previewVC.view

        configure(with: model)
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

    func configure(with model: PasteboardModel) {
        let size = previewVC.configure(with: model)
        contentSize = size

        previewVC.onContentInteraction = { [weak self] in
            self?.onContentInteraction?()
        }
        previewVC.onDismiss = { [weak self] in
            self?.close()
        }
    }

    func cleanup() {
        previewVC.cleanup()
    }

    // MARK: - Size Calculation

    /// 根据 model 类型计算 Popover 的最佳尺寸
    static func fitSize(for model: PasteboardModel) -> NSSize {
        let width = clampedWidth(for: model)
        let contentH = ClipPreviewContentView.preferredContentHeight(
            for: model,
            width: width - Const.space12 * 2
        )
        // header(24) + space8 + content + space8 + footer(24) + 上下 inset(space12 * 2)
        let totalH = 24 + Const.space8 + contentH + Const.space8 + 24 + Const.space12 * 2
        let clampedH = min(max(totalH, Const.minPreviewHeight), Const.maxPreviewHeight)
        return NSSize(width: width, height: clampedH)
    }

    // MARK: - Width Calculation

    private static func clampedWidth(for model: PasteboardModel) -> CGFloat {
        switch model.type {
        case .color:
            return 500
        case .file, .link:
            return Const.maxPreviewWidth
        case .image:
            guard let size = model.cachedImageSize, size.width > 0 else {
                return Const.maxPreviewWidth
            }
            let scale = min(
                Const.maxPreviewWidth / size.width,
                Const.maxContentHeight / size.height,
                1.0
            )
            let displayW = ceil(size.width * scale) + Const.space12 * 2
            return min(max(displayW, Const.minPreviewWidth), Const.maxPreviewWidth)
        case .string, .rich:
            if model.length > Const.maxTextSize { return Const.maxPreviewWidth }
            let textWidth = estimatedTextWidth(for: model)
            return min(
                max(textWidth + Const.space12 * 2 + Const.space8 * 2, Const.minPreviewWidth),
                Const.maxPreviewWidth
            )
        case .none:
            return Const.minPreviewWidth
        }
    }

    private static func estimatedTextWidth(for model: PasteboardModel) -> CGFloat {
        let attributed = ClipPreviewContentView.measuringAttributedString(for: model)
        guard attributed.length > 0 else { return Const.minPreviewWidth }

        let maxW = Const.maxPreviewWidth - Const.space12 * 2 - Const.space8 * 2
        let rect = attributed.boundingRect(
            with: NSSize(width: maxW, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return min(ceil(rect.width) + 32, maxW)
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
