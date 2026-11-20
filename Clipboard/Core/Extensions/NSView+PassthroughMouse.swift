//
//  NSView+PassthroughMouse.swift
//  Clipboard
//
//  Created by crown on 2026/4/15
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
