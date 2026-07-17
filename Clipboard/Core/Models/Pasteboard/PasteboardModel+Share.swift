//
//  PasteboardModel+Share.swift
//  Clipboard
//
//  分享内容提取
//

import AppKit

extension PasteboardModel {
    var shareableItems: [Any] {
        switch type {
        case .file:
            return cachedFilePaths?.compactMap { URL(fileURLWithPath: $0) } ?? []
        case .image:
            return NSImage(data: data).map { [$0] } ?? []
        case .link:
            let str = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: str) {
                return [url]
            }
            return [str]
        case .string, .rich, .color:
            let text = plainText
            return text.isEmpty ? [] : [text]
        case .none:
            return []
        }
    }
}
