//
//  PasteboardType.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit

typealias PasteboardType = NSPasteboard.PasteboardType

extension PasteboardType {
    static var supportTypes: [PasteboardType] = [
        .rtf, .rtfd, .png, .tiff, .fileURL, .string,
    ]

    func isImage() -> Bool {
        self == .png || self == .tiff
    }

    func isText() -> Bool { !isImage() && !isFile() }

    func isPlainText() -> Bool { self == .string }

    func isFile() -> Bool {
        self == .fileURL
    }
}
