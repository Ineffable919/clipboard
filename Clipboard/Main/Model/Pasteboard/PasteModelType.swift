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
        case .image: "图片"
        case .string, .rich: "文本"
        case .color: "颜色"
        case .link: "链接"
        case .file: "文件"
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
            ("photo", "图片")
        case .string, .rich:
            ("text.document", "文本")
        case .file:
            ("folder", "文件")
        case .link:
            ("link", "链接")
        case .color:
            ("paintpalette", "颜色")
        case .none:
            ("", "")
        }
    }
}
