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

    override func mouseDown(with event: NSEvent) {
        if event.type == .leftMouseDown {
            let point = convert(event.locationInWindow, from: nil)
            if let indexPath = indexPathForItem(at: point) {
                onMouseDownBeforeSelection?(indexPath)
            }
        }
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { onBecomeFirstResponder?() }
        return result
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        super.draggingSession(session, movedTo: screenPoint)
        onDragMoved?(screenPoint)
    }

    override func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        super.draggingSession(session, endedAt: screenPoint, operation: operation)

        if #unavailable(macOS 26.0) {
            onDragEnded?(screenPoint)
        }
    }
}
