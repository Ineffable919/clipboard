//
//  PasteboardModel+Styling.swift
//  Clipboard
//
//  颜色计算、搜索高亮、AttributedString 相关逻辑
//

import AppKit
import SwiftUI

extension PasteboardModel {
    var colorDisplayText: String {
        let raw = attributeString.string
        return raw.hasPrefix("#") ? raw : "#\(raw)"
    }

    // MARK: - 纯函数：根据模型给出背景与前景色

    func colors() -> (Color, Color) {
        ensureColorsComputed()
        return (
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
            return (
                Color(hex: attributeString.string),
                getContrastingColor(baseNS: colorNS), true
            )
        }

        if pasteboardType == .string || type == .link {
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

    func highlightedPlainText(keyword: String) -> AttributedString {
        let trimmedKeyword = keyword.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedKeyword.isEmpty else {
            return AttributedString(attributeString.string)
        }

        if let cachedHighlightedPlainText {
            return cachedHighlightedPlainText
        }

        let source: String =
            if pasteboardType.isFile() || pasteboardType.isImage() {
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

        cachedHighlightedPlainText = attributed
        return attributed
    }

    func highlightedRichText(keyword: String) -> NSAttributedString {
        let trimmedKeyword = keyword.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedKeyword.isEmpty else {
            return attributeString
        }

        let mutable = NSMutableAttributedString(
            attributedString: attributeString
        )
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

        return mutable
    }

    func needsBottomMask(compute: () -> Bool) -> Bool {
        if let cachedNeedsBottomMask {
            return cachedNeedsBottomMask
        }
        let value = compute()
        cachedNeedsBottomMask = value
        return value
    }

    /// 将富文本渲染为固定尺寸的 NSImage，供拖拽预览使用。
    func richDragPreviewImage(
        keyword: String = "",
        size: CGSize? = nil,
        inset: CGSize? = nil
    ) -> NSImage {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDefaultSize = size == nil && inset == nil
        if trimmed.isEmpty, isDefaultSize, let cachedDragPreviewRichImage {
            return cachedDragPreviewRichImage
        }

        let drawingSize = size ?? CGSize(width: Const.cardSize, height: Const.cntSize)
        let drawingRect = CGRect(origin: .zero, size: drawingSize)
        let dx = inset?.width ?? Const.space10
        let dy = inset?.height ?? Const.space8
        let insetRect = drawingRect.insetBy(dx: dx, dy: dy)
        let source = trimmed.isEmpty ? attributeString : highlightedRichText(keyword: trimmed)

        let bgColor: NSColor = if attributeString.length > 0,
                                  let bg = attributeString.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor
        {
            bg
        } else {
            .clear
        }

        let image = NSImage(size: drawingSize)
        image.lockFocus()
        bgColor.setFill()
        NSBezierPath.fill(drawingRect)
        source.draw(in: insetRect)
        image.unlockFocus()

        if trimmed.isEmpty, isDefaultSize {
            cachedDragPreviewRichImage = image
        }
        return image
    }

    private func normalizedDisplayString(_ string: String) -> String {
        string
            .replacing("\r\n", with: "\n")
            .replacing("\r", with: "\n")
    }
}
