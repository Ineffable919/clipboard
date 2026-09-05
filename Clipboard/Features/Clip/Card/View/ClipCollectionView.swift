//
//  ClipCollectionView.swift
//  Clipboard
//

import AppKit

final class ClipCollectionView: NSCollectionView {
    var onMouseDownBeforeSelection: ((_ indexPath: IndexPath) -> Void)?
    var onBecomeFirstResponder: (() -> Void)?
    var onDragMoved: ((_ screenPoint: NSPoint) -> Void)?
    var onDragEnded: ((_ screenPoint: NSPoint) -> Void)?
    var onShiftClick: ((_ indexPath: IndexPath) -> Void)?
    var onCollapseToSingle: ((_ indexPath: IndexPath) -> Void)?
    private var pendingCollapse: IndexPath?
    private var didDrag = false
    private let dropLine = CALayer()

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

    var keepsDragSelection: Bool { pendingCollapse != nil }

    override func mouseDown(with event: NSEvent) {
        pendingCollapse = nil
        didDrag = false
        if event.type == .leftMouseDown {
            let point = convert(event.locationInWindow, from: nil)
            let modifiers = event.modifierFlags

            if let indexPath = indexPathForItem(at: point) {
                if modifiers.contains(.shift), !modifiers.contains(.command) {
                    onShiftClick?(indexPath)
                    return
                }

                if !modifiers.contains(.command),
                   selectionIndexPaths.count > 1,
                   selectionIndexPaths.contains(indexPath) {
                    pendingCollapse = indexPath
                    super.mouseDown(with: event)
                    return
                }

                onMouseDownBeforeSelection?(indexPath)
            }
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if let pendingCollapse, !didDrag {
            onCollapseToSingle?(pendingCollapse)
        }
        pendingCollapse = nil
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
        didDrag = true
        super.draggingSession(session, movedTo: screenPoint)
        onDragMoved?(screenPoint)
    }

    override func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        didDrag = true
        pendingCollapse = nil
        hideDropLine()
        super.draggingSession(session, endedAt: screenPoint, operation: operation)

        if #unavailable(macOS 26.0) {
            onDragEnded?(screenPoint)
        }
    }
}
