//
//  PasteboardType.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit

typealias PasteboardType = NSPasteboard.PasteboardType

extension PasteboardType {
    static let pasteboardModel = PasteboardType("com.clipboard.pasteboardModel")

    static var supportTypes: [PasteboardType] = [
        .rtf, .rtfd, .fileURL, .png, .tiff, .string, .pasteboardModel,
    ]

    func isImage() -> Bool {
        self == .png || self == .tiff
    }

    func isText() -> Bool {
        !isImage() && !isFile()
    }

    func isPlainText() -> Bool {
        self == .string
    }

    func isFile() -> Bool {
        self == .fileURL
    }
}
