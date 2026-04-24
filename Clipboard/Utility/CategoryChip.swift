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

    static let palette: [Color] = [
        .gray,
        .blue,
        .green,
        .purple,
        .red,
        .orange,
        .yellow,
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

        switch id {
        case -1:
            return nil
        case -2:
            return [
                PasteboardType.string.rawValue,
                PasteboardType.rtf.rawValue,
                PasteboardType.rtfd.rawValue,
            ]
        case -3:
            return [
                PasteboardType.png.rawValue,
                PasteboardType.tiff.rawValue,
            ]
        case -4:
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
        .init(
            id: -1,
            name: String(localized: .clipboard),
            color: .gray,
            isSystem: true
        ),
    ]
}
