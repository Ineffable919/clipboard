//
//  TokenAttachment.swift
//  Clipboard
//
//  Token 附件，用于在搜索框中渲染筛选标签
//

import AppKit

final class TokenAttachment: NSTextAttachment {
    let tag: InputTag

    // MARK: - Layout Constants

    static let lineHeight: CGFloat = 20

    var isSelected: Bool = false {
        didSet { (attachmentCell as? TokenAttachmentCell)?.isSelected = isSelected }
    }

    init(tag: InputTag) {
        self.tag = tag
        super.init(data: nil, ofType: nil)
        attachmentCell = TokenAttachmentCell(tag: tag)
    }

    override nonisolated init(data _: Data?, ofType _: String?) {
        fatalError("Use init(tag:) instead")
    }

    @available(*, unavailable)
    required nonisolated init?(coder _: NSCoder) {
        nil
    }
}

// MARK: - TokenAttachmentCell

private final class TokenAttachmentCell: NSTextAttachmentCell {
    private let inputTag: InputTag
    var isSelected: Bool = false

    private let hPad: CGFloat = 6
    private let gap: CGFloat = 4
    private let iconSize: CGFloat = 14

    /// Slightly more visible than quaternaryLabelColor, adapts to light/dark
    private static let bgColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 1, alpha: 0.15)
            : NSColor(white: 0, alpha: 0.1)
    }

    init(tag: InputTag) {
        inputTag = tag
        super.init(textCell: "")
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("Use init(tag:) instead")
    }

    // MARK: - Sizing

    private func chipFont() -> NSFont {
        .preferredFont(forTextStyle: .callout)
    }

    private nonisolated func labelSize() -> NSSize {
        MainActor.assumeIsolated {
            let attrs: [NSAttributedString.Key: Any] = [.font: chipFont()]
            return (inputTag.label as NSString).size(withAttributes: attrs)
        }
    }

    override nonisolated func cellSize() -> NSSize {
        MainActor.assumeIsolated {
            let textSize = labelSize()
            var width = hPad * 2 + textSize.width
            if inputTag.icon != nil { width += iconSize + gap }
            return NSSize(width: ceil(width), height: TokenAttachment.lineHeight)
        }
    }

    // MARK: - Baseline

    override nonisolated func cellBaselineOffset() -> NSPoint {
        MainActor.assumeIsolated {
            let font = chipFont()
            let textLineHeight = font.ascender + abs(font.descender)
            let topPadding = (TokenAttachment.lineHeight - textLineHeight) / 2
            let baselineOffset = topPadding + font.ascender
            let y = baselineOffset - TokenAttachment.lineHeight
            return NSPoint(x: 0, y: y)
        }
    }

    // MARK: - Drawing

    override func draw(withFrame cellFrame: NSRect, in _: NSView?) {
        let bg = NSBezierPath(
            roundedRect: cellFrame,
            xRadius: cellFrame.height / 2,
            yRadius: cellFrame.height / 2
        )
        Self.bgColor.setFill()
        bg.fill()

        if #unavailable(macOS 26), isSelected {
            NSColor.selectedTextBackgroundColor.withAlphaComponent(0.4).setFill()
            bg.fill()
        }

        var x = cellFrame.minX + hPad

        if let icon = inputTag.icon {
            let iconRect = NSRect(
                x: x,
                y: cellFrame.midY - iconSize / 2,
                width: iconSize,
                height: iconSize
            )
            let displayIcon: NSImage
            if icon.isTemplate,
               let colored = icon.withSymbolConfiguration(
                   .init(paletteColors: [.labelColor])
               ) {
                displayIcon = colored
            } else {
                displayIcon = icon
            }
            displayIcon.draw(in: iconRect)
            x += iconSize + gap
        }

        let font = chipFont()
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]
        let textOrigin = NSPoint(
            x: x,
            y: cellFrame.midY - font.ascender + font.capHeight / 2
        )
        (inputTag.label as NSString).draw(at: textOrigin, withAttributes: textAttrs)
    }
}

// MARK: - Helper

extension NSAttributedString {
    static func makeToken(for tag: InputTag) -> NSAttributedString {
        let attachment = TokenAttachment(tag: tag)
        return NSAttributedString(attachment: attachment)
    }
}
