import AppKit

/// 限制长行的单次排版范围，保留原文字符和选区坐标
nonisolated final class JSONTypesetter: NSATSTypesetter {
    override func setParagraphGlyphRange(_ range: NSRange, separatorGlyphRange separator: NSRange) {
        let limit = 4096
        guard range.length > limit else {
            super.setParagraphGlyphRange(range, separatorGlyphRange: separator)
            return
        }
        super.setParagraphGlyphRange(
            NSRange(location: range.location, length: limit),
            separatorGlyphRange: NSRange(location: range.location + limit, length: 0)
        )
    }
}
