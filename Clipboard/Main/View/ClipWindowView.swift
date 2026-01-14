//
//  ClipWindowView.swift
//  clipboard
//
//  Created by crown on 2025/9/11.
//

import Cocoa

final class ClipWindowView: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
