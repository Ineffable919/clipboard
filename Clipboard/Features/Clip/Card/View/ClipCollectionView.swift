//
//  ClipCollectionView.swift
//  Clipboard
//

import AppKit

final class ClipCollectionView: NSCollectionView {
    var onBecomeFirstResponder: (() -> Void)?
    var onDragMoved: ((_ screenPoint: NSPoint) -> Void)?
    var onDragEnded: ((_ screenPoint: NSPoint) -> Void)?
    var onShiftClick: ((_ indexPath: IndexPath) -> Void)?
    var onClick: ((_ indexPath: IndexPath) -> Void)?
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
        guard let frame = collectionViewLayout?.layoutAttributesForInterItemGap(before: indexPath)?.frame,
              !frame.isEmpty, let layer
        else {
            hideDropLine()
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
            dropLine.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.65).cgColor
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
        // Shift 范围由点击回调统一设置，代理不再叠加系统的范围选择
        guard onShiftClick != nil, let event = NSApp.currentEvent,
              [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(event.type)
        else { return false }
        let modifiers = clickGesture.clickModifiers
        return modifiers.contains(.shift) && !modifiers.contains(.command)
    }

    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        guard let indexPath = indexPathForItem(at: gesture.location(in: self)) else { return }
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
        }
        return result
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        super.draggingSession(session, movedTo: screenPoint)
        onDragMoved?(screenPoint)
    }

    override func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        hideDropLine()
        super.draggingSession(session, endedAt: screenPoint, operation: operation)

        if #unavailable(macOS 26.0) {
            onDragEnded?(screenPoint)
        }
    }
}
