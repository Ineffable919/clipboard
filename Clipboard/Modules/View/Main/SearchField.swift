//
//  SearchField.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit

final class SearchField: NSSearchField {
    var isEditing = false
    var isFirstResponder: Bool {
        currentEditor() != nil && currentEditor() == window?.firstResponder
    }

    override var canBecomeKeyView: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }
}
