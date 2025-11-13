//
//  NScolor+Extension.swift
//  clipboard
//
//  Created by crown on 2025/9/12.
//

import AppKit
import Cocoa

extension NSColor {
    convenience init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }

    /// 将 NSColor 转为十六进制字符串 (#RRGGBB 或 #RRGGBBAA)
    /// - Parameter includeAlpha: 是否包含 alpha 分量，默认 false
    /// - Returns: 类似 "#FF3366" 或 "#FF3366CC"
    func toHexString(includeAlpha: Bool = false) -> String? {
        guard let rgbColor = usingColorSpace(.sRGB) else { return nil }

        let r = rgbColor.redComponent
        let g = rgbColor.greenComponent
        let b = rgbColor.blueComponent
        let a = rgbColor.alphaComponent

        if includeAlpha {
            return String(
                format: "#%02lX%02lX%02lX%02lX",
                lroundf(Float(r * 255)),
                lroundf(Float(g * 255)),
                lroundf(Float(b * 255)),
                lroundf(Float(a * 255))
            )
        } else {
            return String(
                format: "#%02lX%02lX%02lX",
                lroundf(Float(r * 255)),
                lroundf(Float(g * 255)),
                lroundf(Float(b * 255))
            )
        }
    }

}
