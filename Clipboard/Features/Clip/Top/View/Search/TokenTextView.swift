//
//  TokenTextView.swift
//  Clipboard
//
//  支持 Token 的文本视图，处理 Token 插入、删除和光标控制
//

import AppKit

final class TokenTextView: NSTextView, NSLayoutManagerDelegate {
    private enum Metrics {
        static let height: CGFloat = 28
        static let horizontalInset: CGFloat = 6
        /// 垂直内边距：使行高在容器中垂直居中
        /// (scrollView height - lineHeight) / 2 = (28 - 20) / 2 = 4
        static let verticalInset: CGFloat = 4
    }

    // MARK: - Factory

    static func makeConfigured() -> TokenTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(
            size: NSSize(width: CGFloat.greatestFiniteMagnitude,
                         height: Metrics.height)
        )
        container.widthTracksTextView = false
        container.heightTracksTextView = true
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = 1
        container.lineBreakMode = .byTruncatingTail
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)

        let textView = TokenTextView(frame: .zero, textContainer: container)
        layout.delegate = textView
        textView.isRichText = true
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .labelColor
        if #available(macOS 15.0, *) {
            textView.writingToolsBehavior = .none
        }
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false

        textView.restorePlainTextInputState()
        textView.defaultParagraphStyle = Self.fixedParagraphStyle
        textView.textContainerInset = NSSize(
            width: Metrics.horizontalInset,
            height: Metrics.verticalInset
        )
        textView.minSize = NSSize(width: 0, height: Metrics.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: Metrics.height)
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width, .height]

        return textView
    }

    // MARK: - Properties

    var containerCornerRadius: CGFloat = Const.radius
    var placeholderString: String?

    var onTokenDeleted: ((InputTag) -> Void)?
    var onTextChanged: ((String) -> Void)?
    var onBecomeFirstResponder: (() -> Void)?
    var onResignFirstResponder: (() -> Void)?
    var onKeyDown: ((NSEvent) -> Bool)?

    // MARK: - Layout Constants

    private static let baselineFont: NSFont = .preferredFont(forTextStyle: .body)

    private static let fixedParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = TokenAttachment.lineHeight
        style.maximumLineHeight = TokenAttachment.lineHeight
        return style
    }()

    var plainTextAttributes: [NSAttributedString.Key: Any] {
        [
            .font: font as Any,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: Self.fixedParagraphStyle
        ]
    }

    override var typingAttributes: [NSAttributedString.Key: Any] {
        didSet {
            let current = typingAttributes[.paragraphStyle] as? NSParagraphStyle
            if current?.minimumLineHeight != TokenAttachment.lineHeight {
                typingAttributes[.paragraphStyle] = Self.fixedParagraphStyle
            }
        }
    }

    func restorePlainTextInputState() {
        typingAttributes = plainTextAttributes
    }

    private func updateTextAppearance() {
        textColor = .labelColor

        if let storage = textStorage, storage.length > 0 {
            let selectedRange = selectedRange()
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
                guard value == nil else { return }
                storage.addAttributes(plainTextAttributes, range: range)
            }
            storage.endEditing()
            setSelectedRange(selectedRange)
        }

        restorePlainTextInputState()
        needsDisplay = true
    }

    func moveCursorToEnd() {
        let end = textStorage?.length ?? 0
        setSelectedRange(NSRange(location: end, length: 0))
        restorePlainTextInputState()
        scrollRangeToVisible(selectedRange())
    }

    // MARK: - Overrides

    override func keyDown(with event: NSEvent) {
        if let onKeyDown, onKeyDown(event) {
            return
        }
        super.keyDown(with: event)
    }

    override func deleteBackward(_ sender: Any?) {
        let range = selectedRange()

        if deleteSelectedTokens(in: range) {
            return
        }

        if range.length == 0,
           range.location > 0,
           deleteTokenBeforeCursor(at: range.location - 1) {
            return
        }

        super.deleteBackward(sender)
        notifyTextChanged()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let layoutManager, let textContainer else {
            super.mouseDown(with: event)
            return
        }

        let index = layoutManager.characterIndex(
            for: point,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        if index < (textStorage?.length ?? 0),
           textStorage?.attribute(.attachment, at: index, effectiveRange: nil) != nil {
            setSelectedRange(NSRange(location: index, length: 1))
            return
        }

        super.mouseDown(with: event)
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let range = replacementRange.location == NSNotFound ? selectedRange() : replacementRange

        if isInTokenArea(range.location) {
            let tokenEnd = findTokenEndIndex()
            setSelectedRange(NSRange(location: tokenEnd, length: 0))
            restorePlainTextInputState()
        }

        super.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
        notifyTextChanged()
    }

    private func isInTokenArea(_ location: Int) -> Bool {
        location < findTokenEndIndex()
    }

    override func didChangeText() {
        super.didChangeText()
        scrollRangeToVisible(selectedRange())
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTextAppearance()
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            onBecomeFirstResponder?()
            moveCursorToEnd()
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        clearSelectedToken()
        let result = super.resignFirstResponder()
        if result {
            onResignFirstResponder?()
        }
        return result
    }

    private func clearSelectedToken() {
        let selection = selectedRange()
        guard selection.length == 1,
              let storage = textStorage,
              selection.location < storage.length,
              storage.attribute(.attachment, at: selection.location, effectiveRange: nil) is TokenAttachment
        else { return }

        setSelectedRange(NSRange(location: NSMaxRange(selection), length: 0))
        restorePlainTextInputState()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let placeholder = placeholderString,
              (textStorage?.length ?? 0) == 0
        else { return }

        let font = Self.baselineFont
        let baselineOffset = TokenAttachment.alignedBaseline(for: font)
        let topPadding = baselineOffset - font.ascender

        let origin = NSPoint(
            x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0),
            y: textContainerInset.height + topPadding
        )

        let placeholderColor = NSColor.labelColor.withAlphaComponent(0.62)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: placeholderColor
        ]
        (placeholder as NSString).draw(at: origin, withAttributes: attrs)
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        if #unavailable(macOS 26) {
            syncTokenSelectionState()
        }
    }

    private func syncTokenSelectionState() {
        guard let storage = textStorage else { return }
        let sel = selectedRange()
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            guard let attachment = value as? TokenAttachment else { return }
            attachment.isSelected = sel.length > 0 && NSIntersectionRange(sel, range).length > 0
        }
    }

    func layoutManager(
        _: NSLayoutManager,
        shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>,
        lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
        baselineOffset: UnsafeMutablePointer<CGFloat>,
        in _: NSTextContainer,
        forGlyphRange _: NSRange
    ) -> Bool {
        let font = Self.baselineFont
        let fixedLineHeight = TokenAttachment.lineHeight

        lineFragmentRect.pointee.size.height = fixedLineHeight
        lineFragmentUsedRect.pointee.size.height = fixedLineHeight

        baselineOffset.pointee = TokenAttachment.alignedBaseline(for: font)

        return true
    }
}
