//
//  RichTextEditorView.swift
//  Clipboard
//
//  Created by crown on 2025/12/28.
//

import AppKit
import SnapKit

// MARK: - FormatAction

enum FormatAction {
    case bold
    case italic
    case underline
    case strikethrough
}

final class RichTextEditorView: NSView {
    // MARK: - Callbacks

    var onTextChange: (() -> Void)?

    // MARK: - Subviews

    private let scrollView: NSScrollView
    private let textView: NSTextView

    /// 当前编辑内容
    var currentContent: NSAttributedString {
        textView.attributedString()
    }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        let scroll = NSTextView.scrollableTextView()
        let text = (scroll.documentView as? NSTextView) ?? NSTextView()
        if scroll.documentView !== text {
            scroll.documentView = text
        }
        scrollView = scroll
        textView = text
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.importsGraphics = false
        textView.allowsImageEditing = false

        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.delegate = self

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Content

    func setContent(_ attributedString: NSAttributedString) {
        let cleaned = Self.removeColorAttributes(from: attributedString)
        let adapted = Self.applyAdaptiveTextColor(to: cleaned)
        textView.textStorage?.setAttributedString(adapted)
    }

    // MARK: - Format Actions

    func applyFormat(_ action: FormatAction) {
        guard let textStorage = textView.textStorage else { return }

        let selectedRange = textView.selectedRange()
        guard selectedRange.length > 0 else { return }

        textStorage.beginEditing()

        switch action {
        case .bold:
            applyBold(to: textStorage, range: selectedRange)
        case .italic:
            applyItalic(to: textStorage, range: selectedRange)
        case .underline:
            applyUnderline(to: textStorage, range: selectedRange)
        case .strikethrough:
            applyStrikethrough(to: textStorage, range: selectedRange)
        }

        textStorage.endEditing()

        onTextChange?()
    }

    private func applyBold(to storage: NSTextStorage, range: NSRange) {
        storage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let currentFont =
                (value as? NSFont)
                    ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let fontManager = NSFontManager.shared

            let newFont: NSFont =
                if fontManager.traits(of: currentFont).contains(.boldFontMask) {
                    fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
                } else {
                    fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
                }

            storage.addAttribute(.font, value: newFont, range: subRange)
        }
    }

    private func applyItalic(to storage: NSTextStorage, range: NSRange) {
        storage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let currentFont =
                (value as? NSFont)
                    ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let fontManager = NSFontManager.shared

            let newFont: NSFont =
                if fontManager.traits(of: currentFont).contains(.italicFontMask) {
                    fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
                } else {
                    fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
                }

            storage.addAttribute(.font, value: newFont, range: subRange)
        }
    }

    private func applyUnderline(to storage: NSTextStorage, range: NSRange) {
        var hasUnderline = false

        storage.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, stop in
            if let style = value as? Int, style != 0 {
                hasUnderline = true
                stop.pointee = true
            }
        }

        if hasUnderline {
            storage.removeAttribute(.underlineStyle, range: range)
        } else {
            storage.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: range
            )
        }
    }

    private func applyStrikethrough(to storage: NSTextStorage, range: NSRange) {
        var hasStrikethrough = false

        storage.enumerateAttribute(.strikethroughStyle, in: range, options: []) { value, _, stop in
            if let style = value as? Int, style != 0 {
                hasStrikethrough = true
                stop.pointee = true
            }
        }

        if hasStrikethrough {
            storage.removeAttribute(.strikethroughStyle, range: range)
        } else {
            storage.addAttribute(
                .strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: range
            )
        }
    }

    // MARK: - Color Helpers

    private static func removeColorAttributes(
        from attributedString: NSAttributedString
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.removeAttribute(.foregroundColor, range: fullRange)
        mutable.removeAttribute(.backgroundColor, range: fullRange)

        return mutable
    }

    private static func applyAdaptiveTextColor(
        to attributedString: NSAttributedString
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            if value == nil {
                mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
            }
        }

        return mutable
    }
}

// MARK: - NSTextViewDelegate

extension RichTextEditorView: NSTextViewDelegate {
    func textDidChange(_: Notification) {
        onTextChange?()
    }
}
