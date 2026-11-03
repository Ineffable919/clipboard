//
//  HorizontalScrollView.swift
//  Clipboard
//
//  Created by crown on 2026/4/10
//

import AppKit

final class HorizontalScrollView: AnimatedScrollView {
    override var hasVerticalScroller: Bool {
        get { false }
        set { /* ignore */ }
    }

    override var hasHorizontalScroller: Bool {
        get { false }
        set { /* ignore */ }
    }

    // MARK: - Focus Ring

    weak var focusRingMaskView: NSView? {
        didSet { noteFocusRingMaskChanged() }
    }

    var isFocusRingSuppressed = false {
        didSet {
            guard isFocusRingSuppressed != oldValue else { return }
            noteFocusRingMaskChanged()
        }
    }

    override var focusRingType: NSFocusRingType {
        get { focusRingMaskView == nil ? super.focusRingType : .exterior }
        set { super.focusRingType = newValue }
    }

    override var focusRingMaskBounds: NSRect {
        guard let focusRingMaskView else { return super.focusRingMaskBounds }
        guard !isFocusRingSuppressed else { return .zero }
        return maskRect(of: focusRingMaskView)
    }

    /// 遮罩视图正在做图层动画时，焦点环跟随呈现层的位置与宽度
    private func maskRect(of view: NSView) -> NSRect {
        var rect = view.convert(view.bounds, to: self)
        guard let layer = view.layer, layer.animationKeys()?.isEmpty == false,
              let live = layer.presentation() else { return rect }
        rect.origin.x += live.frame.minX - layer.frame.minX
        rect.size.width += live.bounds.width - layer.bounds.width
        return rect
    }

    override func drawFocusRingMask() {
        guard let focusRingMaskView else {
            super.drawFocusRingMask()
            return
        }
        guard !isFocusRingSuppressed else { return }
        let cornerRadius = focusRingMaskView.layer?.cornerRadius ?? 0
        NSBezierPath(
            roundedRect: maskRect(of: focusRingMaskView),
            xRadius: cornerRadius,
            yRadius: cornerRadius
        ).fill()
    }

    override func scrollWheel(with event: NSEvent) {
        let isTrackpad = event.phase != [] || event.momentumPhase != []
        guard !isTrackpad else {
            super.scrollWheel(with: event)
            return
        }

        // 鼠标滚轮：将垂直滚动转换为水平滚动
        if event.scrollingDeltaX == 0,
           let cgEvent = event.cgEvent?.copy() {
            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: Double(event.scrollingDeltaY))
            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: 0.0)
            let redirected = NSEvent(cgEvent: cgEvent) ?? event
            super.scrollWheel(with: redirected)
        } else {
            super.scrollWheel(with: event)
        }
    }
}
