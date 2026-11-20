//
//  PressDownGestureRecognizer.swift
//  Clipboard
//
//  Created by crown on 2026/11/3
//

import AppKit

final class PressDownGestureRecognizer: NSGestureRecognizer {
    override func mouseDown(with _: NSEvent) {
        state = .ended
    }
}
