//
//  Color+Extension.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import SwiftUI

extension Color {
    /// 从 hex 字符串创建 Color
    /// - Parameter hex: 十六进制颜色字符串，支持 "#RRGGBB" 或 "RRGGBB" 格式
    nonisolated init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacing("#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
