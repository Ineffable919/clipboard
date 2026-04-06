//
//  CardTextView.swift
//  Clipboard
//
//  Created by crown on 2026/3/31.
//

import AppKit
import SwiftUI

struct CardTextView: NSViewRepresentable {
    let attributedString: NSAttributedString
    var isSelectable: Bool = false
    var inset: NSSize = .init(width: Const.space10, height: Const.space8)
    var backgroundColor: NSColor?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastWidth: CGFloat = 0
        var lastAttributedString: NSAttributedString?
    }

    func makeNSView(context: Context) -> PassthroughTextView {
        let textView = PassthroughTextView(usingTextLayoutManager: false)
        textView.isEditable = false
        textView.isSelectable = isSelectable
        if let bg = backgroundColor {
            textView.drawsBackground = true
            textView.backgroundColor = bg
        } else {
            textView.drawsBackground = false
        }
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.wantsLayer = true

        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.layoutManager?.allowsNonContiguousLayout = false

        textView.textContainerInset = inset

        textView.textContainer?.containerSize = CGSize(
            width: Const.cardSize - Const.space10 * 2,
            height: CGFloat.greatestFiniteMagnitude
        )

        textView.textStorage?.setAttributedString(attributedString)
        context.coordinator.lastAttributedString = attributedString

        return textView
    }

    func updateNSView(_ textView: PassthroughTextView, context: Context) {
        textView.isSelectable = isSelectable
        textView.textContainerInset = inset
        if let bg = backgroundColor {
            textView.drawsBackground = true
            textView.backgroundColor = bg
        } else {
            textView.drawsBackground = false
            textView.backgroundColor = .clear
        }
        applyTextIfNeeded(to: textView, context: context)

        let width: CGFloat =
            if context.coordinator.lastWidth > 0 {
                context.coordinator.lastWidth
            } else if textView.frame.width > 0 {
                textView.frame.width
            } else {
                Const.cardSize
            }

        if let container = textView.textContainer,
            let layoutManager = textView.layoutManager
        {
            let inset = textView.textContainerInset
            container.containerSize = CGSize(
                width: max(width - inset.width * 2, 0),
                height: CGFloat.greatestFiniteMagnitude
            )
            layoutManager.ensureLayout(for: container)
        }
        textView.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: PassthroughTextView,
        context: Context
    ) -> CGSize? {
        guard let container = nsView.textContainer,
            let layoutManager = nsView.layoutManager
        else { return nil }

        applyTextIfNeeded(to: nsView, context: context)

        let inset = nsView.textContainerInset
        let width = proposal.width ?? Const.cardSize
        context.coordinator.lastWidth = width

        container.containerSize = CGSize(
            width: max(width - inset.width * 2, 0),
            height: CGFloat.greatestFiniteMagnitude
        )
        layoutManager.ensureLayout(for: container)

        let usedHeight = layoutManager.usedRect(for: container).height
        let maxHeight = proposal.height ?? CGFloat.greatestFiniteMagnitude
        let textHeight = min(usedHeight + inset.height * 2, maxHeight)
        if backgroundColor != nil, let proposedHeight = proposal.height {
            return CGSize(width: width, height: max(textHeight, proposedHeight))
        }
        return CGSize(width: width, height: textHeight)
    }

    private func applyTextIfNeeded(
        to textView: PassthroughTextView,
        context: Context
    ) {
        guard context.coordinator.lastAttributedString !== attributedString
        else { return }
        context.coordinator.lastAttributedString = attributedString
        textView.textStorage?.setAttributedString(attributedString)
    }
}

// MARK: - PassthroughTextView

/// 将鼠标事件透传给父视图，确保 SwiftUI 的点击和拖拽手势正常工作
final class PassthroughTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        // 可选中模式下保留默认行为（文本选择）
        if isSelectable {
            super.mouseDown(with: event)
        } else {
            nextResponder?.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if isSelectable {
            super.mouseDragged(with: event)
        } else {
            nextResponder?.mouseDragged(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isSelectable {
            super.mouseUp(with: event)
        } else {
            nextResponder?.mouseUp(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }
}
