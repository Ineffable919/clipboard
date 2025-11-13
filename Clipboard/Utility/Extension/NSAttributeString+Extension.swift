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
            try? self.init(data: data, options: [:], documentAttributes: nil)
        default:
            return nil
        }
    }

    func toData(with type: PasteboardType) -> Data? {
        switch type {
        case .rtf:
            return rtf(from: NSMakeRange(0, length))
        case .rtfd:
            return rtfd(from: NSMakeRange(0, length))
        case .string:
            return try? data(from: NSMakeRange(0, length))
        default:
            return nil
        }
    }
}
