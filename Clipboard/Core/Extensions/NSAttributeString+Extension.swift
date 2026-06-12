//
//  NSAttributeString+Extension.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit

extension NSAttributedString {
    convenience init?(with data: Data?, type: PasteboardType) {
        guard let data else { return nil }
        switch type {
        case .rtf:
            self.init(rtf: data, documentAttributes: nil)
        case .rtfd:
            self.init(rtfd: data, documentAttributes: nil)
        case .string:
            if let string = String(data: data, encoding: .utf8) {
                self.init(string: string)
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    func toData(with type: PasteboardType) -> Data? {
        switch type {
        case .rtf:
            rtf(from: NSMakeRange(0, length))
        case .rtfd:
            rtfd(from: NSMakeRange(0, length))
        case .string:
            string.data(using: .utf8)
        default:
            nil
        }
    }
}
