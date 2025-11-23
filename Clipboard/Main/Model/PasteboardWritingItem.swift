//
//  PasteboardWritingItem.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit

final class PasteboardWritingItem: NSObject {
    private let data: Data
    private let type: PasteboardType

    init(data: Data, type: PasteboardType) {
        self.data = data
        self.type = type
    }
}

extension PasteboardWritingItem: NSPasteboardWriting {
    func writableTypes(for _: NSPasteboard) -> [PasteboardType] {
        [type]
    }

    func pasteboardPropertyList(forType _: PasteboardType) -> Any? {
        data
    }
}
