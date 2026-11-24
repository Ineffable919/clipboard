//
//  ClipCollectionView.swift
//  Clipboard
//
//  Created by crown on 2026/4/11
//

import AppKit

final class ClipCollectionView: NSCollectionView {
    var onBecomeFirstResponder: (() -> Void)?
    var onDragMoved: ((_ screenPoint: NSPoint) -> Void)?
    var onDragEnded: ((_ screenPoint: NSPoint) -> Void)?
    var onShiftClick: ((_ indexPath: IndexPath) -> Void)?
    var onClick: ((_ indexPath: IndexPath) -> Void)?
    var onInteractionFocus: (() -> Void)?
    private lazy var clickGesture = CollectionClickGestureRecognizer(
        target: self,
        action: #selector(handleClick(_:))
    )
    private let dropLine = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        clickGesture.delaysPrimaryMouseButtonEvents = false
        addGestureRecognizer(clickGesture)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func showDropLine(before indexPath: IndexPath) {
        guard
            let frame = collectionViewLayout?.layoutAttributesForInterItemGap(
                before: indexPath
            )?.frame,
            !frame.isEmpty, let layer
        else {
            hideDropLine()
            return
        }
        guard dropLine.superlayer == nil || dropLine.frame != frame else {
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if dropLine.superlayer == nil {
            layer.addSublayer(dropLine)
        }
        dropLine.frame = frame
        dropLine.cornerRadius = frame.width / 2
        dropLine.zPosition = 10
        effectiveAppearance.performAsCurrentDrawingAppearance {
            dropLine.backgroundColor =
                NSColor.controlAccentColor.withAlphaComponent(0.65).cgColor
        }
        dropLine.isHidden = false
        CATransaction.commit()
    }

    func hideDropLine() {
        dropLine.removeFromSuperlayer()
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        super.draggingExited(sender)
        hideDropLine()
    }

    var handlesShiftSelection: Bool {
        guard onShiftClick != nil, let event = NSApp.currentEvent,
            [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(
                event.type
            )
        else { return false }
        let modifiers = clickGesture.clickModifiers
        return modifiers.contains(.shift) && !modifiers.contains(.command)
    }

    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        defer { onInteractionFocus?() }
        guard let indexPath = indexPathForItem(at: gesture.location(in: self))
        else { return }
        let modifiers = clickGesture.clickModifiers
        if modifiers.contains(.shift), !modifiers.contains(.command) {
            onShiftClick?(indexPath)
        } else if !modifiers.contains(.command) {
            onClick?(indexPath)
        }
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            onBecomeFirstResponder?()
            if NSApp.currentEvent?.type == .keyDown {
                onInteractionFocus?()
            }
        }
        return result
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func beginDraggingSession(
        with items: [NSDraggingItem],
        event: NSEvent,
        source: any NSDraggingSource
    ) -> NSDraggingSession {
        // AppKit 在开始拖拽前隐藏源卡片，同一事务内恢复，避免渲染出空帧
        for item in visibleItems() where item.view.isHidden {
            item.view.isHidden = false
        }
        return super.beginDraggingSession(with: items, event: event, source: source)
    }

    override func draggingSession(
        _ session: NSDraggingSession,
        willBeginAt screenPoint: NSPoint
    ) {
        super.draggingSession(session, willBeginAt: screenPoint)
        onInteractionFocus?()
    }

    override func draggingSession(
        _ session: NSDraggingSession,
        movedTo screenPoint: NSPoint
    ) {
        super.draggingSession(session, movedTo: screenPoint)
        onDragMoved?(screenPoint)
    }

    override func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        hideDropLine()
        super.draggingSession(
            session,
            endedAt: screenPoint,
            operation: operation
        )

        if #unavailable(macOS 26.0) {
            onDragEnded?(screenPoint)
        }
    }
}
