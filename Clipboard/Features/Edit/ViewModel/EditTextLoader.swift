//
//  EditTextLoader.swift
//  Clipboard
//

import AppKit

enum EditTextLoader {
    nonisolated static func load(data: Data, typeRawValue: String) -> String {
        let type = NSPasteboard.PasteboardType(typeRawValue)

        if type == .string {
            return String(decoding: data, as: UTF8.self)
        }

        return autoreleasepool {
            let attributedString: NSAttributedString? = switch type {
            case .rtf:
                NSAttributedString(rtf: data, documentAttributes: nil)
            case .rtfd:
                NSAttributedString(rtfd: data, documentAttributes: nil)
            default:
                nil
            }
            return attributedString?.string
                ?? String(decoding: data, as: UTF8.self)
        }
    }
}
