//
//  TokenAttachment.swift
//  Clipboard
//
//  Token 附件，用于在搜索框中渲染筛选标签
//

import AppKit

final class TokenAttachment: NSTextAttachment {
    let tag: InputTag

    init(tag: InputTag) {
        self.tag = tag
        super.init(data: nil, ofType: nil)
        image = Self.makeChipImage(for: tag)
        bounds = Self.makeBounds(for: tag)
    }

    override nonisolated init(data _: Data?, ofType _: String?) {
        fatalError("Use init(tag:) instead")
    }

    @available(*, unavailable)
    required nonisolated init?(coder _: NSCoder) {
        nil
    }

    // MARK: - Layout Constants

    private static let hPad: CGFloat = 6
    private static let gap: CGFloat = 4
    private static let iconSize: CGFloat = 14

    static let lineHeight: CGFloat = 20

    // MARK: - Drawing

    private static func chipFont() -> NSFont {
        .preferredFont(forTextStyle: .callout)
    }

    private static func textAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: chipFont(),
            .foregroundColor: NSColor.labelColor,
        ]
    }

    private static func chipSize(for tag: InputTag) -> NSSize {
        let attrs = textAttributes()
        let textSize = (tag.label as NSString).size(withAttributes: attrs)
        var width = hPad * 2 + textSize.width
        if tag.icon != nil { width += iconSize + gap }
        return NSSize(width: ceil(width), height: lineHeight)
    }

    private static func makeChipImage(for tag: InputTag) -> NSImage {
        let size = chipSize(for: tag)
        let attrs = textAttributes()
        let textSize = (tag.label as NSString).size(withAttributes: attrs)

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let pixelWidth = Int(size.width * scale)
        let pixelHeight = Int(size.height * scale)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: size)
        }

        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let rect = NSRect(origin: .zero, size: size)

        let bg = NSBezierPath(
            roundedRect: rect,
            xRadius: rect.height / 2,
            yRadius: rect.height / 2
        )
        NSColor(white: 0, alpha: 0.08).setFill()
        bg.fill()

        var x = hPad

        if let icon = tag.icon {
            let iconRect = NSRect(
                x: x,
                y: rect.midY - iconSize / 2,
                width: iconSize,
                height: iconSize
            )
            icon.draw(
                in: iconRect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: false,
                hints: nil
            )
            x += iconSize + gap
        }

        let textRect = NSRect(
            x: x,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        (tag.label as NSString).draw(in: textRect, withAttributes: attrs)

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    private static func makeBounds(for tag: InputTag) -> CGRect {
        let size = chipSize(for: tag)
        let font = chipFont()
        let textLineHeight = font.ascender + abs(font.descender)
        let topPadding = (lineHeight - textLineHeight) / 2
        let baselineOffset = topPadding + font.ascender
        let y = baselineOffset - lineHeight
        return CGRect(x: 0, y: y, width: size.width, height: size.height)
    }
}

// MARK: - Helper

extension NSAttributedString {
    static func makeToken(for tag: InputTag) -> NSAttributedString {
        let attachment = TokenAttachment(tag: tag)
        return NSAttributedString(attachment: attachment)
    }
}
