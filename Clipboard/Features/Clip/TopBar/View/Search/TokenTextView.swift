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

        let tv = TokenTextView(frame: .zero, textContainer: container)
        layout.delegate = tv
        tv.isRichText = true
        tv.drawsBackground = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.font = .preferredFont(forTextStyle: .callout)
        tv.textColor = .labelColor
        tv.writingToolsBehavior = .none
        tv.isAutomaticDataDetectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false

        tv.applyTypingAttributes()
        tv.defaultParagraphStyle = Self.fixedParagraphStyle
        tv.textContainerInset = NSSize(
            width: Metrics.horizontalInset,
            height: Metrics.verticalInset
        )
        tv.minSize = NSSize(width: 0, height: Metrics.height)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: Metrics.height)
        tv.isVerticallyResizable = false
        tv.isHorizontallyResizable = true
        tv.autoresizingMask = [.width, .height]

        return tv
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

    private static let baselineFont: NSFont = .preferredFont(forTextStyle: .callout)

    private static let fixedParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = TokenAttachment.lineHeight
        style.maximumLineHeight = TokenAttachment.lineHeight
        return style
    }()

    private var plainTextAttributes: [NSAttributedString.Key: Any] {
        [
            .font: font as Any,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: Self.fixedParagraphStyle,
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

    // MARK: - Token Management

    func insertToken(_ tag: InputTag) {
        insertTokens([tag])
    }

    func insertTokens(_ tags: [InputTag]) {
        guard !tags.isEmpty, let storage = textStorage else { return }

        storage.beginEditing()
        for tag in tags {
            let insertIndex = findTokenEndIndex()
            storage.insert(NSAttributedString.makeToken(for: tag), at: insertIndex)
            storage.insert(
                NSAttributedString(string: " ", attributes: plainTextAttributes),
                at: insertIndex + 1
            )
        }
        storage.endEditing()

        moveCursorToEnd()
        notifyTextChanged()
    }

    func removeToken(_ tag: InputTag) {
        guard let storage = textStorage else { return }

        let fullRange = NSRange(location: 0, length: storage.length)
        var foundRange: NSRange?

        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, stop in
            if let attachment = value as? TokenAttachment, attachment.tag == tag {
                foundRange = range
                stop.pointee = true
            }
        }

        guard let range = foundRange else { return }

        storage.beginEditing()
        let deleteRange = NSRange(
            location: range.location,
            length: min(range.length + 1, storage.length - range.location)
        )
        storage.deleteCharacters(in: deleteRange)
        storage.endEditing()

        setSelectedRange(NSRange(location: min(range.location, storage.length), length: 0))
        notifyTextChanged()
    }

    func clearAllTokens() {
        guard let storage = textStorage else { return }

        let fullRange = NSRange(location: 0, length: storage.length)
        var rangesToDelete: [NSRange] = []

        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if value is NSTextAttachment { rangesToDelete.append(range) }
        }

        storage.beginEditing()
        for range in rangesToDelete.reversed() {
            let deleteRange = NSRange(
                location: range.location,
                length: min(range.length + 1, storage.length - range.location)
            )
            storage.deleteCharacters(in: deleteRange)
        }
        storage.endEditing()

        setSelectedRange(NSRange(location: 0, length: 0))
        notifyTextChanged()
    }

    func getAllTokens() -> [InputTag] {
        guard let storage = textStorage else { return [] }

        var tokens: [InputTag] = []
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, _, _ in
            if let attachment = value as? TokenAttachment {
                tokens.append(attachment.tag)
            }
        }

        return tokens
    }

    func getPlainText() -> String {
        guard let storage = textStorage else { return "" }

        let mutableString = NSMutableString(string: storage.string)
        let fullRange = NSRange(location: 0, length: storage.length)
        var rangesToDelete: [NSRange] = []

        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if value is NSTextAttachment { rangesToDelete.append(range) }
        }

        for range in rangesToDelete.reversed() {
            mutableString.deleteCharacters(in: range)
        }

        return mutableString.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Private Helpers

    private func findTokenEndIndex() -> Int {
        guard let storage = textStorage else { return 0 }

        var lastTokenEnd = 0
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if value is NSTextAttachment {
                lastTokenEnd = max(lastTokenEnd, range.location + range.length + 1)
            }
        }

        return lastTokenEnd
    }

    private func notifyTextChanged() {
        onTextChanged?(getPlainText())
    }

    private func applyTypingAttributes() {
        typingAttributes = plainTextAttributes
    }

    private func updateTextAppearance() {
        textColor = .labelColor
        insertionPointColor = .labelColor
        applyTypingAttributes()

        guard let storage = textStorage, storage.length > 0 else { return }

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

    private func moveCursorToEnd() {
        let end = textStorage?.length ?? 0
        setSelectedRange(NSRange(location: end, length: 0))
        applyTypingAttributes()
        scrollRangeToVisible(selectedRange())
    }

    // MARK: - Overrides

    override func keyDown(with event: NSEvent) {
        if let onKeyDown, onKeyDown(event) { return }
        super.keyDown(with: event)
    }

    override func deleteBackward(_ sender: Any?) {
        let range = selectedRange()

        guard range.length == 0, range.location > 0 else {
            if range.length > 0, let storage = textStorage {
                var tokensInRange: [InputTag] = []
                storage.enumerateAttribute(.attachment, in: range, options: []) { value, _, _ in
                    if let attachment = value as? TokenAttachment {
                        tokensInRange.append(attachment.tag)
                    }
                }

                if !tokensInRange.isEmpty {
                    let storageLength = storage.length
                    var extendedEnd = range.location + range.length
                    if extendedEnd < storageLength {
                        let nextChar = (storage.string as NSString).character(at: extendedEnd)
                        if nextChar == unichar((" " as UnicodeScalar).value) {
                            extendedEnd += 1
                        }
                    }
                    let deleteRange = NSRange(
                        location: range.location,
                        length: min(extendedEnd - range.location, storageLength - range.location)
                    )
                    storage.beginEditing()
                    storage.deleteCharacters(in: deleteRange)
                    storage.endEditing()
                    setSelectedRange(NSRange(location: range.location, length: 0))

                    for tag in tokensInRange {
                        onTokenDeleted?(tag)
                    }
                    notifyTextChanged()
                    return
                }
            }
            super.deleteBackward(sender)
            notifyTextChanged()
            return
        }

        let prevLoc = range.location - 1

        if let attachment = textStorage?.attribute(.attachment, at: prevLoc, effectiveRange: nil) as? TokenAttachment {
            onTokenDeleted?(attachment.tag)

            textStorage?.beginEditing()
            let deleteRange = NSRange(
                location: prevLoc,
                length: min(2, (textStorage?.length ?? 0) - prevLoc)
            )
            textStorage?.deleteCharacters(in: deleteRange)
            textStorage?.endEditing()

            setSelectedRange(NSRange(location: prevLoc, length: 0))
            notifyTextChanged()
        } else {
            super.deleteBackward(sender)
            notifyTextChanged()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        guard let lm = layoutManager, let tc = textContainer else {
            super.mouseDown(with: event)
            return
        }

        let idx = lm.characterIndex(
            for: pt,
            in: tc,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        if idx < (textStorage?.length ?? 0),
           textStorage?.attribute(.attachment, at: idx, effectiveRange: nil) != nil
        {
            setSelectedRange(NSRange(location: idx, length: 1))
            return
        }

        super.mouseDown(with: event)
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let range = replacementRange.location == NSNotFound ? selectedRange() : replacementRange

        if isInTokenArea(range.location) {
            let tokenEnd = findTokenEndIndex()
            setSelectedRange(NSRange(location: tokenEnd, length: 0))
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
        let result = super.resignFirstResponder()
        if result {
            if #unavailable(macOS 26) { syncTokenSelectionState() }
            onResignFirstResponder?()
        }
        return result
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let placeholder = placeholderString,
              (textStorage?.length ?? 0) == 0
        else { return }

        let font = Self.baselineFont
        let fixedLineHeight = TokenAttachment.lineHeight
        let textLineHeight = font.ascender + abs(font.descender)
        let topPadding = (fixedLineHeight - textLineHeight) / 2

        let origin = NSPoint(
            x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0),
            y: textContainerInset.height + topPadding
        )

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        (placeholder as NSString).draw(at: origin, withAttributes: attrs)
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        if #unavailable(macOS 26) { syncTokenSelectionState() }
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
        let textLineHeight = font.ascender + abs(font.descender)
        let topPadding = (fixedLineHeight - textLineHeight) / 2

        lineFragmentRect.pointee.size.height = fixedLineHeight
        lineFragmentUsedRect.pointee.size.height = fixedLineHeight

        baselineOffset.pointee = topPadding + font.ascender

        return true
    }
}
