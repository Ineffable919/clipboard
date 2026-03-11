//
//  PasteboardModel+Styling.swift
//  Clipboard
//
//  颜色计算、搜索高亮、AttributedString 相关逻辑
//

import AppKit
import SwiftUI

extension PasteboardModel {
    var backgroundColor: Color {
        cachedBackgroundColor ?? .clear
    }

    var hasBgColor: Bool {
        cachedHasBackgroundColor
    }

    // MARK: - 纯函数：根据模型给出背景与前景色

    func colors() -> (Color, Color) {
        (
            cachedBackgroundColor ?? Color(.controlBackgroundColor),
            cachedForegroundColor ?? .secondary
        )
    }

    func computeColors() -> (Color, Color, Bool) {
        let fallbackBG = Color(.controlBackgroundColor)
        guard pasteboardType.isText() else {
            return (fallbackBG, .secondary, false)
        }

        if type == .color {
            let colorNS = NSColor(hex: attributeString.string)
            return (Color(hex: attributeString.string), getContrastingColor(baseNS: colorNS), true)
        }

        if pasteboardType == .string {
            return (fallbackBG, .secondary, false)
        }
        if attributeString.length > 0,
           let bg = attributeString.attribute(
               .backgroundColor,
               at: 0,
               effectiveRange: nil
           ) as? NSColor
        {
            return (Color(bg), getContrastingColor(baseNS: bg), true)
        }
        return (fallbackBG, .secondary, false)
    }

    private func getContrastingColor(baseNS: NSColor) -> Color {
        let c = baseNS.usingColorSpace(.sRGB) ?? baseNS
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        return brightness > 0.5 ? .black.opacity(0.8) : .white.opacity(0.8)
    }

    /// 在 sRGB 空间基于亮度粗分（用于富文本背景）
    private func getRTFColor(baseNS: NSColor) -> Color {
        let c = baseNS.usingColorSpace(.sRGB) ?? baseNS
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        return brightness > 0.7
            ? Color.black.opacity(0.5) : Color.white.opacity(0.5)
    }

    func attributed() -> AttributedString {
        if let cachedAttributed { return cachedAttributed }
        let attr = AttributedString(attributeString)
        cachedAttributed = attr
        return attr
    }

    func highlightedPlainText(keyword: String) -> AttributedString {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else {
            return AttributedString(attributeString.string)
        }

        if cachedHighlightedPlainKeyword == trimmedKeyword,
           let cachedHighlightedPlainText
        {
            return cachedHighlightedPlainText
        }

        let source: String = if pasteboardType.isFile() {
            searchText
        } else {
            attributeString.string
        }
        var attributed = AttributedString(source)

        let options: String.CompareOptions = [
            .caseInsensitive,
            .diacriticInsensitive,
            .widthInsensitive,
        ]

        var searchStart = source.startIndex
        while searchStart < source.endIndex,
              let range = source.range(
                  of: trimmedKeyword,
                  options: options,
                  range: searchStart ..< source.endIndex,
                  locale: .current
              )
        {
            if let attributedRange = Range(range, in: attributed) {
                attributed[attributedRange].backgroundColor =
                    Color.yellow.opacity(0.65)
            }
            searchStart = range.upperBound
        }

        cachedHighlightedPlainKeyword = trimmedKeyword
        cachedHighlightedPlainText = attributed
        return attributed
    }

    func highlightedRichText(keyword: String) -> AttributedString {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else {
            return attributed()
        }

        if cachedHighlightedRichKeyword == trimmedKeyword,
           let cachedHighlightedRichText
        {
            return cachedHighlightedRichText
        }

        let mutable = NSMutableAttributedString(attributedString: attributeString)
        let string = mutable.string as NSString

        let options: NSString.CompareOptions = [
            .caseInsensitive,
            .diacriticInsensitive,
            .widthInsensitive,
        ]

        var searchRange = NSRange(location: 0, length: string.length)
        while searchRange.length > 0 {
            let found = string.range(
                of: trimmedKeyword,
                options: options,
                range: searchRange,
                locale: .current
            )

            if found.location == NSNotFound {
                break
            }

            mutable.addAttribute(
                .backgroundColor,
                value: NSColor.systemYellow.withAlphaComponent(0.65),
                range: found
            )

            let nextLocation = found.location + found.length
            guard nextLocation < string.length else { break }
            searchRange = NSRange(
                location: nextLocation,
                length: string.length - nextLocation
            )
        }

        let highlighted = AttributedString(mutable)
        cachedHighlightedRichKeyword = trimmedKeyword
        cachedHighlightedRichText = highlighted
        return highlighted
    }

    func needsBottomMask(compute: () -> Bool) -> Bool {
        if let cachedNeedsBottomMask {
            return cachedNeedsBottomMask
        }
        let value = compute()
        cachedNeedsBottomMask = value
        return value
    }
}
