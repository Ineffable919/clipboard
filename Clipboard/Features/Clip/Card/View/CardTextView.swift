import AppKit

/// 卡片只读预览保留 TextKit 排版与富文本属性，不创建编辑器视图
final class CardTextView: CardRasterView {
    private let textStorage = NSTextStorage()
    private let textLayout = NSLayoutManager()
    private let textContainer = NSTextContainer(size: .zero)

    var backgroundColor: NSColor? {
        didSet { invalidateContents() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        textLayout.addTextContainer(textContainer)
        textStorage.addLayoutManager(textLayout)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    func setText(_ text: NSAttributedString, font: NSFont? = nil) {
        textStorage.setAttributedString(text)
        if let font {
            textStorage.addAttribute(.font, value: font, range: NSRange(location: 0, length: textStorage.length))
        }
        setAccessibilityValue(text.string)
        invalidateContents()
    }

    override func drawContents(in bounds: NSRect) {
        if let backgroundColor {
            backgroundColor.setFill()
            bounds.fill()
        }
        let origin = NSPoint(x: Const.space10, y: Const.space8)
        let textBounds = NSRect(
            x: 0, y: 0,
            width: max(bounds.width - origin.x * 2, 0),
            height: max(bounds.height - origin.y, 0)
        )
        let size = NSSize(width: textBounds.width, height: .greatestFiniteMagnitude)
        if textContainer.containerSize != size {
            textContainer.containerSize = size
        }
        textLayout.ensureLayout(forBoundingRect: textBounds, in: textContainer)
        let range = textLayout.glyphRange(forBoundingRect: textBounds, in: textContainer)
        textLayout.drawBackground(forGlyphRange: range, at: origin)
        textLayout.drawGlyphs(forGlyphRange: range, at: origin)
    }
}
