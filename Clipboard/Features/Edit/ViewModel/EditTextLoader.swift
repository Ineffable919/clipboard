//
//  EditTextLoader.swift
//  Clipboard
//

import AppKit

enum EditTextLoader {
    nonisolated static func load(data: Data, typeRawValue: String) -> String {
        let type = NSPasteboard.PasteboardType(typeRawValue)

        if type == .string {
            return decode(data)
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
                ?? decode(data)
        }
    }

    private nonisolated static func decode(_ data: Data) -> String {
        // 剪贴板损坏的 UTF-8 仍需显示替代字符，不能改为返回空文本
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: data, as: UTF8.self)
    }
}
