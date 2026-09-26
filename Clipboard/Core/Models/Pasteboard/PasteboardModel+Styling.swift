//
//  PasteboardModel+Styling.swift
//  Clipboard
//
//  颜色计算、搜索高亮、AttributedString 相关逻辑
//

import AppKit

extension PasteboardModel {
    var colorDisplayText: String {
        let raw = attributeString.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return !raw.isEmpty && raw.allSatisfy(\.isHexDigit) ? "#\(raw)" : raw
    }

    // MARK: - 颜色

    /// 富文本背景色，alpha ≤ 0.01 的视为透明返回 nil
    var safeBgColor: NSColor? {
        guard let c = cachedBackgroundColor else { return nil }
        let srgb = c.usingColorSpace(.sRGB) ?? c
        return srgb.alphaComponent > 0.01 ? srgb : nil
    }

    /// 只为没有有效背景的文字补底色，不修改富文本本身
    func richBackground(on background: NSColor, forPreview: Bool = false) -> NSColor? {
        guard hasBgColor else { return nil }
        if let safeBgColor { return safeBgColor }

        let foregrounds = (forPreview ? cachedPreviewForegrounds ?? [] : cachedRichForegrounds)
            .compactMap { $0.usingColorSpace(.sRGB) }

        guard !foregrounds.isEmpty,
              let background = background.usingColorSpace(.sRGB)
        else { return nil }

        func minimumContrast(on color: NSColor) -> CGFloat {
            foregrounds.reduce(CGFloat(21)) { min($0, textContrast($1, on: color)) }
        }

        guard minimumContrast(on: background) < 4.5 else { return nil }
        let light = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let dark = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        let lightContrast = minimumContrast(on: light)
        let darkContrast = minimumContrast(on: dark)
        let candidate = lightContrast >= darkContrast ? light : dark
        // 深浅文字混排时，只有所有无背景片段都清晰才切换整块底色
        return max(lightContrast, darkContrast) >= 4.5 ? candidate : nil
    }

    /// 完整预览首次加载后分析；空数组也缓存，避免反复扫描无适配需求的文本
    func cachePreviewColors(_ content: NSAttributedString) {
        guard cachedPreviewForegrounds == nil else { return }
        cachedPreviewForegrounds = hasBgColor && safeBgColor == nil
            ? Self.richForegrounds(in: content) : []
    }

    static func richForegrounds(in content: NSAttributedString) -> [NSColor] {
        var colors = Set<NSColor>()
        let source = content.string as NSString
        let visibleCharacters = CharacterSet.whitespacesAndNewlines.inverted
        content.enumerateAttributes(in: NSRange(location: 0, length: content.length)) { attributes, range, _ in
            if let background = attributes[.backgroundColor] as? NSColor,
               background.alphaComponent > 0.01 { return }
            guard attributes[.attachment] == nil else { return }
            let foreground = attributes[.foregroundColor] as? NSColor ?? .textColor
            guard !colors.contains(foreground),
                  source.rangeOfCharacter(from: visibleCharacters, options: [], range: range).location != NSNotFound
            else { return }
            // 保留动态颜色，使用时再按视图主题解析；相同颜色只参与一次对比度计算。
            colors.insert(foreground)
        }
        return Array(colors)
    }

    func colors() -> (NSColor, NSColor) {
        if type == .rich {
            if let background = richBackground(on: .textBackgroundColor) {
                return (background, contrastingNSColor(for: background))
            }
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
        if let cachedNeedsBottomMask {
            return cachedNeedsBottomMask
        }
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

private func textContrast(_ foreground: NSColor, on background: NSColor) -> CGFloat {
    func luminance(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGFloat {
        func linear(_ value: CGFloat) -> CGFloat {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    let alpha = foreground.alphaComponent
    let back = luminance(background.redComponent, background.greenComponent, background.blueComponent)
    let front = luminance(
        foreground.redComponent * alpha + background.redComponent * (1 - alpha),
        foreground.greenComponent * alpha + background.greenComponent * (1 - alpha),
        foreground.blueComponent * alpha + background.blueComponent * (1 - alpha)
    )
    return (max(front, back) + 0.05) / (min(front, back) + 0.05)
}

func contrastingNSColor(for color: NSColor) -> NSColor {
    let c = color.usingColorSpace(.sRGB) ?? color
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    c.getRed(&r, green: &g, blue: &b, alpha: &a)
    let brightness = 0.299 * r + 0.587 * g + 0.114 * b
    return brightness > 0.5
        ? NSColor.black.withAlphaComponent(0.8)
        : NSColor.white.withAlphaComponent(0.8)
}
