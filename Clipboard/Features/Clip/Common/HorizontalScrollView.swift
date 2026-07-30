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
