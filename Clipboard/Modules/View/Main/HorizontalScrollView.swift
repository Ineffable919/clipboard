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
