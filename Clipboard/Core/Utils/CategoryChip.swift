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

    private static let semanticPalette: [Color] = [
        .gray,
        .blue,
        .green,
        .purple,
        .red,
        .orange,
        .yellow,
    ]

    static let paletteNSColors: [NSColor] = [
        .systemGray,
        .systemBlue,
        .systemGreen,
        .systemPurple,
        .systemRed,
        .systemOrange,
        .systemYellow,
    ]

    static let palette = paletteNSColors.map { Color(nsColor: $0) }

    static func nsColor(at index: Int) -> NSColor {
        guard index >= 0, index < paletteNSColors.count else {
            return paletteNSColors[0]
        }
        return paletteNSColors[index]
    }

    var color: Color {
        get {
            guard colorIndex >= 0, colorIndex < CategoryChip.palette.count
            else {
                return .gray
            }
            return CategoryChip.palette[colorIndex]
        }
        set {
            if let index = CategoryChip.semanticPalette.firstIndex(of: newValue)
                ?? CategoryChip.palette.firstIndex(of: newValue) {
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

        if let index = CategoryChip.semanticPalette.firstIndex(of: color)
            ?? CategoryChip.palette.firstIndex(of: color) {
            colorIndex = index
        } else {
            colorIndex = 0
        }
    }

    init(id: Int, name: String, colorIndex: Int, isSystem: Bool) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.isSystem = isSystem
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
