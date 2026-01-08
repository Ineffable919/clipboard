//
//  CategoryChip.swift
//  Clipboard
//
//  Created by crown on 2025/9/21.
//

import SwiftUI

struct CategoryChip: Identifiable, Equatable, Codable {
    let id: Int
    var name: String
    var colorIndex: Int // 存储颜色在调色板中的索引
    var isSystem: Bool

    // 全局调色板，后续可以直接在这里添加新颜色
    static let palette: [Color] = [
        .gray,
        .blue,
        .green,
        .purple,
        .red,
        .orange,
        .yellow,
        .pink,
        .cyan,
        .brown,
        .indigo,
    ]

    var color: Color {
        get {
            guard colorIndex >= 0, colorIndex < CategoryChip.palette.count
            else {
                return .gray
            }
            return CategoryChip.palette[colorIndex]
        }
        set {
            if let index = CategoryChip.palette.firstIndex(of: newValue) {
                colorIndex = index
            } else {
                colorIndex = 0
            }
        }
    }

    var typeFilter: [String]? {
        guard isSystem else { return nil }

        switch name {
        case "文本":
            return [
                PasteboardType.string.rawValue,
                PasteboardType.rtf.rawValue,
                PasteboardType.rtfd.rawValue,
            ]
        case "图片":
            return [
                PasteboardType.png.rawValue,
                PasteboardType.tiff.rawValue,
            ]
        case "文件":
            return [PasteboardType.fileURL.rawValue]
        default:
            return nil
        }
    }

    init(id: Int, name: String, color: Color, isSystem: Bool) {
        self.id = id
        self.name = name
        self.isSystem = isSystem

        if let index = CategoryChip.palette.firstIndex(of: color) {
            colorIndex = index
        } else {
            colorIndex = 0
        }
    }

    static let systemChips: [CategoryChip] = [
        .init(id: -1, name: "剪贴板", color: .gray, isSystem: true),
    ]
}
