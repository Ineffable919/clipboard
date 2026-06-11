//
//  PasteboardModel+Styling.swift
//  Clipboard
//
//  颜色计算、搜索高亮、AttributedString 相关逻辑
//

import AppKit

extension PasteboardModel {
    var colorDisplayText: String {
        let raw = attributeString.string
        return raw.hasPrefix("#") ? raw : "#\(raw)"
    }

    // MARK: - 颜色

    /// 富文本背景色，alpha ≤ 0.01 的视为透明返回 nil
    var safeBgColor: NSColor? {
        guard let c = cachedBackgroundColor else { return nil }
        let srgb = c.usingColorSpace(.sRGB) ?? c
        return srgb.alphaComponent > 0.01 ? srgb : nil
    }

    func colors() -> (NSColor, NSColor) {
        if type == .rich, cachedBackgroundColor != nil, safeBgColor == nil {
            return (.textBackgroundColor, .secondaryLabelColor)
        }
        return (
            cachedBackgroundColor ?? .textBackgroundColor,
            cachedForegroundColor ?? .secondaryLabelColor
        )
    }

    func computeColors() -> (NSColor?, NSColor?, Bool) {
        guard pasteboardType.isText() else {
            return (nil, nil, false)
        }

        if type == .color {
            let bg = NSColor(hex: attributeString.string)
            return (bg, contrastingNSColor(for: bg), true)
        }

        if pasteboardType == .string || type == .link {
            return (nil, nil, false)
        }

        if attributeString.length > 0,
           let bg = attributeString.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor
        {
            return (bg, contrastingNSColor(for: bg), true)
        }
        return (nil, nil, false)
    }

    // MARK: - 高亮

    func highlightedNSAttributedString(keyword: String) -> NSAttributedString {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return plainTextAttributedString }

        let source = attributeString.string
        let mutable = NSMutableAttributedString(string: source)
        attributeString.enumerateAttributes(
            in: NSRange(location: 0, length: attributeString.length)
        ) { attrs, range, _ in
            mutable.addAttributes(attrs, range: range)
        }

        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)

        applyHighlight(to: mutable, source: source as NSString, keyword: trimmed)
        return mutable
    }

    var plainTextAttributedString: NSAttributedString {
        let source = attributeString.string
        let mutable = NSMutableAttributedString(string: source)
        attributeString.enumerateAttributes(
            in: NSRange(location: 0, length: attributeString.length)
        ) { attrs, range, _ in
            mutable.addAttributes(attrs, range: range)
        }
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        return mutable
    }

    func highlightedRichText(keyword: String) -> NSAttributedString {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return attributeString }

        let mutable = NSMutableAttributedString(attributedString: attributeString)
        applyHighlight(to: mutable, source: mutable.string as NSString, keyword: trimmed)
        return mutable
    }

    func highlightedPlainText(keyword: String) -> NSAttributedString {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = attributeString.string
        let mutable = NSMutableAttributedString(string: source)
        guard !trimmed.isEmpty else { return mutable }
        applyHighlight(to: mutable, source: source as NSString, keyword: trimmed)
        return mutable
    }

    // MARK: - Bottom mask

    func needsBottomMask(compute: () -> Bool) -> Bool {
        if let cachedNeedsBottomMask { return cachedNeedsBottomMask }
        let value = compute()
        cachedNeedsBottomMask = value
        return value
    }

    // MARK: - Private helpers

    private func applyHighlight(
        to mutable: NSMutableAttributedString,
        source: NSString,
        keyword: String
    ) {
        let options: NSString.CompareOptions = [
            .caseInsensitive, .diacriticInsensitive, .widthInsensitive,
        ]
        var searchRange = NSRange(location: 0, length: source.length)
        while searchRange.length > 0 {
            let found = source.range(of: keyword, options: options, range: searchRange, locale: .current)
            guard found.location != NSNotFound else { break }
            mutable.addAttribute(
                .backgroundColor,
                value: NSColor.systemYellow.withAlphaComponent(0.65),
                range: found
            )
            let next = found.location + found.length
            guard next < source.length else { break }
            searchRange = NSRange(location: next, length: source.length - next)
        }
    }
}

// MARK: - NSColor helpers

func contrastingNSColor(for color: NSColor) -> NSColor {
    let c = color.usingColorSpace(.sRGB) ?? color
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    c.getRed(&r, green: &g, blue: &b, alpha: &a)
    let brightness = 0.299 * r + 0.587 * g + 0.114 * b
    return brightness > 0.5
        ? NSColor.black.withAlphaComponent(0.8)
        : NSColor.white.withAlphaComponent(0.8)
}
