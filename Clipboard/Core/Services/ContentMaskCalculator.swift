//
//  ContentMaskCalculator.swift
//  Clipboard
//
//  Created by crown on 2026/4/12.
//

import AppKit

// MARK: - ContentMaskCalculator

enum ContentMaskCalculator {
    static func needsMask(for model: PasteboardModel) -> Bool {
        guard model.pasteboardType.isText() else { return false }

        let contentTopPadding = Const.space8
        let contentHeightBeforeBottomOverlay = Const.cntSize - Const.bottomSize
        let contentTextHeight = calculateContentTextHeight(model: model)

        return (contentTopPadding + contentTextHeight) > contentHeightBeforeBottomOverlay
    }

    private static func calculateContentTextHeight(model: PasteboardModel) -> CGFloat {
        let availableWidth = Const.cardSize - Const.space10 * 4

        // 修复：用 NSLayoutManager + NSTextContainer 代替 boundingRect
        // 对混合字体、行高、富文本的测量结果更准确
        let attrString = preparedAttributedString(from: model.attributeString)

        let textStorage = NSTextStorage(attributedString: attrString)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: CGSize(width: max(0, availableWidth), height: .greatestFiniteMagnitude)
        )
        textContainer.lineFragmentPadding = 0

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        return ceil(usedRect.height)
    }

    /// 对 attributedString 做最小化预处理：
    /// 1. 统一换行符（\r\n → \n），避免测量偏差
    /// 2. 末尾 \n 补一个空格，让 layoutManager 计入最后一行高度
    /// 3. 对没有 font 的 range 补默认字体，防止 layoutManager 跳过
    /// 注意：不覆盖已有的 paragraphStyle，保留富文本原始行高/段间距
    private static func preparedAttributedString(
        from base: NSAttributedString
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: base)
        let fullRange = NSRange(location: 0, length: mutable.length)
        let defaultFont = NSFont.preferredFont(forTextStyle: .body)

        // 1. 统一换行符
        if mutable.string.contains("\r\n") {
            mutable.mutableString.replaceOccurrences(
                of: "\r\n",
                with: "\n",
                options: [],
                range: fullRange
            )
        }

        // 2. 末尾 \n 补空格
        if mutable.string.hasSuffix("\n") {
            mutable.append(NSAttributedString(string: " ", attributes: [.font: defaultFont]))
        }

        // 3. 修复：遍历所有 run，只对没有 font 的 range 补默认字体
        // 原实现只检查 index 0，会漏掉中间没有 font 的 run
        var location = 0
        while location < mutable.length {
            var effectiveRange = NSRange()
            let font = mutable.attribute(.font, at: location, effectiveRange: &effectiveRange)
            if font == nil {
                mutable.addAttribute(.font, value: defaultFont, range: effectiveRange)
            }
            location = NSMaxRange(effectiveRange)
        }

        return mutable
    }
}

// MARK: - PaddedTextField

final class PaddedTextField: NSTextField {
    let padding: NSEdgeInsets

    init(padding: NSEdgeInsets) {
        self.padding = padding
        super.init(frame: .zero)
        isEditable = false
        isSelectable = false
        isBordered = false
        drawsBackground = false
        cell = PaddedTextFieldCell(padding: padding)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += padding.left + padding.right
        size.height += padding.top + padding.bottom
        return size
    }
}

// MARK: - PaddedTextFieldCell

private final class PaddedTextFieldCell: NSTextFieldCell {
    let padding: NSEdgeInsets

    init(padding: NSEdgeInsets) {
        self.padding = padding
        super.init(textCell: "")
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError()
    }

    /// 手动计算四边，支持不对称的 padding
    private func applyPadding(to rect: NSRect) -> NSRect {
        NSRect(
            x: rect.origin.x + padding.left,
            y: rect.origin.y + padding.top,
            width: max(0, rect.width - padding.left - padding.right),
            height: max(0, rect.height - padding.top - padding.bottom)
        )
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        super.drawingRect(forBounds: applyPadding(to: rect))
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        super.titleRect(forBounds: applyPadding(to: rect))
    }

    override func edit(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        event: NSEvent?
    ) {
        super.edit(
            withFrame: applyPadding(to: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            event: event
        )
    }

    override func select(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        start selStart: Int,
        length selLength: Int
    ) {
        super.select(
            withFrame: applyPadding(to: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            start: selStart,
            length: selLength
        )
    }
}
