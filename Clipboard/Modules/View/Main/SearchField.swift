//
//  SearchField.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import Combine

final class SearchField: NSSearchField {
    
    var isEditing = false
    var isFirstResponder: Bool {
        currentEditor() != nil && currentEditor() == window?.firstResponder
    }

    @Published private(set) var text: String = ""

    override var stringValue: String {
        didSet {
            if stringValue != text {
                text = stringValue
            }
        }
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        text = stringValue
    }

    override var canBecomeKeyView: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }
}
