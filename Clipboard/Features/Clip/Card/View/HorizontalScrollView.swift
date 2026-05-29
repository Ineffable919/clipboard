//
//  HorizontalScrollView.swift
//  Clipboard
//
//  Created by crown on 2026/4/10.
//

import AppKit

final class HorizontalScrollView: NSScrollView {
    override var hasVerticalScroller: Bool {
        get { false }
        set { /* ignore */ }
    }

    override var hasHorizontalScroller: Bool {
        get { false }
        set { /* ignore */ }
    }

    // MARK: - Focus Ring

    /// 焦点环的形状参照视图。设置后,`NSScrollView` 会在它的 document view 成为第一
    /// 响应者时自动调用 `drawFocusRingMask`,据此把系统焦点环画在该视图范围上
    // (滚动视图本身不被裁剪,所以环不会被裁掉)。
    ///
    /// 仅在设置了本属性的实例上启用焦点环;未设置时保持系统默认行为,
    /// 避免给共用本类的其它滚动视图意外加上焦点环。
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
        return focusRingMaskView.convert(focusRingMaskView.bounds, to: self)
    }

    override func drawFocusRingMask() {
        guard let focusRingMaskView else {
            super.drawFocusRingMask()
            return
        }
        guard !isFocusRingSuppressed else { return }
        let cornerRadius = focusRingMaskView.layer?.cornerRadius ?? 0
        NSBezierPath(
            roundedRect: focusRingMaskView.convert(focusRingMaskView.bounds, to: self),
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
           let cgEvent = event.cgEvent?.copy()
        {
            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: Double(event.scrollingDeltaY))
            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: 0.0)
            let redirected = NSEvent(cgEvent: cgEvent) ?? event
            super.scrollWheel(with: redirected)
        } else {
            super.scrollWheel(with: event)
        }
    }
}
