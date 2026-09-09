import AppKit

final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override var attributedStringValue: NSAttributedString {
        get { super.attributedStringValue }
        set {
            guard usesSingleLineMode else {
                super.attributedStringValue = newValue
                return
            }
            let ranges = newValue.string.ranges(of: /\R/)
            var paragraphUpdates: [(NSRange, NSMutableParagraphStyle)] = []
            newValue.enumerateAttribute(
                .paragraphStyle, in: NSRange(location: 0, length: newValue.length)
            ) { value, range, _ in
                let style = value as? NSParagraphStyle ?? .default
                guard style.lineBreakMode != .byTruncatingTail,
                      let updated = style.mutableCopy() as? NSMutableParagraphStyle else { return }
                updated.lineBreakMode = .byTruncatingTail
                paragraphUpdates.append((range, updated))
            }
            guard !ranges.isEmpty || !paragraphUpdates.isEmpty else {
                super.attributedStringValue = newValue
                return
            }
            // 仅转换单行预览，保留原始内容及其文字样式。
            let preview = NSMutableAttributedString(attributedString: newValue)
            for (range, style) in paragraphUpdates {
                preview.addAttribute(.paragraphStyle, value: style, range: range)
            }
            for range in ranges.reversed() {
                preview.replaceCharacters(in: NSRange(range, in: newValue.string), with: " ")
            }
            super.attributedStringValue = preview
        }
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let rect = super.drawingRect(forBounds: rect)
        let textSize = usesSingleLineMode ? cellSize : cellSize(forBounds: rect)
        let heightDelta = rect.height - textSize.height
        guard heightDelta > 0 else { return rect }
        return NSRect(
            x: rect.origin.x,
            y: rect.origin.y + heightDelta / 2,
            width: rect.width,
            height: textSize.height
        )
    }
}
