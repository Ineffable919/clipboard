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
    private var viewport: JSONViewportEditor?

    /// 当前编辑内容
    var currentContent: NSAttributedString {
        viewport?.richContent.map { NSAttributedString(attributedString: $0) } ?? textView.attributedString()
    }

    var currentText: String {
        viewport?.currentText ?? textView.string
    }

    var isEditable: Bool {
        get { viewport?.isEditable ?? textView.isEditable }
        set { textView.isEditable = newValue; viewport?.isEditable = newValue }
    }

    var hasRichFormatting: Bool {
        let content = currentContent
        guard content.length > 0 else { return false }
        let range = NSRange(location: 0, length: content.length)
        var found = false

        content.enumerateAttributes(in: range, options: []) { attributes, _, stop in
            if let underline = attributes[.underlineStyle] as? Int, underline != 0 {
                found = true
            } else if let strikethrough = attributes[.strikethroughStyle] as? Int,
                      strikethrough != 0 {
                found = true
            } else if let font = attributes[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                found = traits.contains(.bold) || traits.contains(.italic)
            }

            if found {
                stop.pointee = true
            }
        }
        return found
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
        textView.layoutManager?.allowsNonContiguousLayout = true
        // 限制长段落的排版范围，避免切换大 JSON 时同步排版全文
        textView.layoutManager?.backgroundLayoutEnabled = false
        textView.layoutManager?.typesetter = JSONTypesetter()

        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 13)
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

    func setText(_ text: String, prepared: JSONPreparedText? = nil) {
        if let prepared {
            installViewport(text, prepared: prepared)
            return
        }
        viewport?.cancelWork()
        viewport?.removeFromSuperview()
        viewport = nil
        scrollView.isHidden = false
        if #available(macOS 15.2, *) {
            // 大文本全选会让 Writing Tools 查询全文选区并触发同步排版
            textView.writingToolsBehavior = text.utf8.count >= 1_048_576 ? .none : .default
        }
        textView.undoManager?.disableUndoRegistration()
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor
        ]
        textView.string = text
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.undoManager?.enableUndoRegistration()
        textView.undoManager?.removeAllActions()
    }

    func focus() {
        if let viewport { viewport.focus(); return }
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        window?.makeFirstResponder(textView)
    }

    func scrollToTop() {
        if let viewport { viewport.scrollToTop(); return }
        let clipView = scrollView.contentView
        var targetBounds = clipView.bounds
        targetBounds.origin = .zero
        let constrainedBounds = clipView.constrainBoundsRect(targetBounds)
        clipView.scroll(to: constrainedBounds.origin)
        scrollView.reflectScrolledClipView(clipView)
    }

    // MARK: - Format Actions

    func applyFormat(_ action: FormatAction) {
        guard let textStorage: NSMutableAttributedString = viewport?.richContent ?? textView.textStorage else { return }
        let selectedRange = viewport?.selection ?? textView.selectedRange()
        guard selectedRange.length > 0 else { return }
        viewport?.registerRichUndo(selectedRange, replacementLength: selectedRange.length)

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
        if let viewport { viewport.refreshRich() } else { onTextChange?() }
    }

    private func applyBold(to storage: NSMutableAttributedString, range: NSRange) {
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

    private func applyItalic(to storage: NSMutableAttributedString, range: NSRange) {
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

    private func applyUnderline(to storage: NSMutableAttributedString, range: NSRange) {
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

    private func applyStrikethrough(to storage: NSMutableAttributedString, range: NSRange) {
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
}

private extension RichTextEditorView {
    func installViewport(_ text: String, prepared: JSONPreparedText) {
        if viewport == nil {
            let editor = JSONViewportEditor()
            editor.enableRichText()
            editor.textView.usesFontPanel = textView.usesFontPanel
            editor.textView.usesRuler = textView.usesRuler
            editor.textView.importsGraphics = textView.importsGraphics
            editor.textView.allowsImageEditing = textView.allowsImageEditing
            editor.textView.isAutomaticQuoteSubstitutionEnabled = textView.isAutomaticQuoteSubstitutionEnabled
            editor.textView.isAutomaticDashSubstitutionEnabled = textView.isAutomaticDashSubstitutionEnabled
            editor.textView.isAutomaticTextReplacementEnabled = textView.isAutomaticTextReplacementEnabled
            editor.textView.isAutomaticSpellingCorrectionEnabled = textView.isAutomaticSpellingCorrectionEnabled
            editor.textView.isContinuousSpellCheckingEnabled = textView.isContinuousSpellCheckingEnabled
            if #available(macOS 15.2, *) { editor.textView.writingToolsBehavior = .none }
            editor.onChange = { [weak self] _ in self?.onTextChange?() }
            addSubview(editor)
            editor.snp.makeConstraints { $0.edges.equalToSuperview() }
            viewport = editor
        }
        scrollView.isHidden = true
        textView.string = ""
        layoutSubtreeIfNeeded()
        viewport?.setText(text, document: nil, prepared: prepared)
    }
}

extension RichTextEditorView {
    func cancelWork() {
        viewport?.cancelWork()
        textView.undoManager?.removeAllActions()
    }
}

// MARK: - NSTextViewDelegate

extension RichTextEditorView: NSTextViewDelegate {
    func textDidChange(_: Notification) {
        onTextChange?()
    }
}
