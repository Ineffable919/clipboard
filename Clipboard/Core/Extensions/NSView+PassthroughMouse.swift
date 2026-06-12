//
//  NSView+PassthroughMouse.swift
//  Clipboard
//

import AppKit

protocol PassthroughMouseEvents: NSView {}

extension PassthroughMouseEvents {
    func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }

    func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }

    func mouseDragged(with event: NSEvent) {
        nextResponder?.mouseDragged(with: event)
    }

    func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }
}
