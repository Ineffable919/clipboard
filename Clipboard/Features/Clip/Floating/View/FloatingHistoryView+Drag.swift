//
//  FloatingHistoryView+Drag.swift
//  Clipboard
//

import AppKit

// MARK: - Drag

extension FloatingHistoryView {
    func handleDragMoved(_ screenPoint: NSPoint) {
        guard let window else { return }
        let visibleRect = convert(bounds, to: nil)
        let screenRect = window.convertToScreen(visibleRect)
        if !screenRect.contains(screenPoint),
           ClipFloatingWindowController.shared.isVisible {
            ClipFloatingWindowController.shared.toggleWindow()
        }
    }

    func handleDragEnded(_ screenPoint: NSPoint) {
        guard let window else { return }
        let visibleRect = convert(bounds, to: nil)
        let screenRect = window.convertToScreen(visibleRect)
        guard screenRect.contains(screenPoint) else { return }

        env.suppressResignKey = true
        window.resignKey()
        window.makeKey()
        window.makeFirstResponder(collectionView)
        env.suppressResignKey = false
    }
}
