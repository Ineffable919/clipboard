//
//  TokenItem.swift
//  Clipboard
//
//  Created by crown on 2026/02/04.
//

import AppKit

struct TokenItem: Identifiable, Equatable {
    let id: UUID
    let label: String
    let icon: NSImage

    init(id: UUID = UUID(), label: String, icon: NSImage) {
        self.id = id
        self.label = label
        self.icon = icon
    }

    static func == (lhs: TokenItem, rhs: TokenItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct TokenSuggestion: Identifiable {
    let id: UUID
    let label: String
    let icon: NSImage?

    init(id: UUID = UUID(), label: String, icon: NSImage? = nil) {
        self.id = id
        self.label = label
        self.icon = icon
    }
}
