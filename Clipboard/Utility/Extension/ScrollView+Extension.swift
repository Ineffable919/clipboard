//
//  ScrollView+Extension.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import SwiftUI

struct HorizontalWheelScrollView<Content: View>: NSViewRepresentable {
    @ViewBuilder var content: () -> Content

    func makeNSView(context _: Context) -> WheelScrollView {
        let scroll = WheelScrollView()
        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.horizontalScrollElasticity = .automatic
        scroll.verticalScrollElasticity = .none

        let hosting = NSHostingView(rootView: content())
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = []
        hosting.postsFrameChangedNotifications = true

        let initialSize = hosting.fittingSize
        hosting.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: max(1, initialSize.width),
                height: max(1, initialSize.height),
            ),
        )

        scroll.documentView = hosting
        return scroll
    }

    func updateNSView(_ scroll: WheelScrollView, context _: Context) {
        if let hosting = scroll.documentView as? NSHostingView<Content> {
            hosting.rootView = content()

            let size = hosting.fittingSize
            hosting.setFrameSize(
                NSSize(
                    width: max(1, size.width),
                    height: max(1, scroll.contentSize.height),
                ),
            )
        }
    }
}

final class WheelScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
            let delta = event.scrollingDeltaY
            let targetX = contentView.bounds.origin.x - delta
            scrollTo(x: targetX)
        } else {
            super.scrollWheel(with: event)
        }
    }

    private func scrollTo(x: CGFloat) {
        let maxX: CGFloat = {
            guard let doc = documentView else { return 0 }
            return max(0, doc.bounds.width - contentView.bounds.width)
        }()

        let clamped = min(max(0, x), maxX)
        contentView.scroll(
            to: NSPoint(x: clamped, y: contentView.bounds.origin.y),
        )
        reflectScrolledClipView(contentView)
    }
}
