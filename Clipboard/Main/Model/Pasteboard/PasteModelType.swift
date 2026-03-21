//
//  PasteModelType.swift
//  Clipboard
//
//  剪贴板内容的语义类型枚举
//

import AppKit

enum PasteModelType: String {
    case none
    case image
    case string
    case rich
    case file
    case link
    case color

    init(with type: PasteboardType, model: PasteboardModel) {
        switch type {
        case .rtf, .rtfd:
            if model.isCSS {
                self = .color
            } else if model.isLink {
                self = .link
            } else {
                self = .rich
            }
        case .string:
            if model.isCSS {
                self = .color
            } else if model.isLink {
                self = .link
            } else {
                self = .string
            }
        case .png, .tiff:
            self = .image
        case .fileURL:
            self = .file
        default:
            self = .none
        }
    }

    var string: String {
        switch self {
        case .image: String(localized: .image)
        case .string, .rich: String(localized: .text)
        case .color: String(localized: .color)
        case .link: String(localized: .link)
        case .file: String(localized: .file)
        default: ""
        }
    }

    var tagValue: String {
        switch self {
        case .none: ""
        case .image: "image"
        case .string: "string"
        case .rich: "rich"
        case .file: "file"
        case .link: "link"
        case .color: "color"
        }
    }

    var iconAndLabel: (icon: String, label: String) {
        switch self {
        case .image:
            ("photo", String(localized: .image))
        case .string, .rich:
            ("text.document", String(localized: .text))
        case .file:
            ("folder", String(localized: .file))
        case .link:
            ("link", String(localized: .link))
        case .color:
            ("paintpalette", String(localized: .color))
        case .none:
            ("", "")
        }
    }
}
