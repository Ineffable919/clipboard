//
//  TokenSearchField.swift
//  Clipboard
//
//  Created by crown on 2026/02/04.
//

import AppKit
import SwiftUI

struct TokenSearchField: NSViewRepresentable {
    @Binding var tokens: [TokenItem]
    @Binding var query: String

    let suggestions: [TokenSuggestion]
    let isFocused: Bool
    let onFocusChange: (Bool) -> Void
    let onTokenInserted: (TokenItem) -> Void
    let onTokenRemoved: (TokenItem) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            tokens: $tokens,
            query: $query,
            suggestions: suggestions,
            onFocusChange: onFocusChange,
            onTokenInserted: onTokenInserted,
            onTokenRemoved: onTokenRemoved
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = TokenTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFontPanel = false
        textView.usesFindPanel = false
        textView.allowsUndo = true
        textView.isAutomaticTextCompletionEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.focusRingType = .none
        textView.drawsBackground = false
        textView.backgroundColor = .clear

        let font = NSFont.preferredFont(forTextStyle: .callout)
        textView.font = font
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]

        textView.textContainerInset = NSSize(width: 6, height: 4)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: 24
        )
        textView.textContainer?.maximumNumberOfLines = 1
        textView.textContainer?.lineBreakMode = .byTruncatingTail

        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 24)
        textView.autoresizingMask = [.width, .height]
        textView.frame = NSRect(x: 0, y: 0, width: 200, height: 24)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.documentView = textView

        context.coordinator.install(textView: textView)
        context.coordinator.syncFromSwiftUI(tokens: tokens, query: query, force: true)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.update(
            suggestions: suggestions,
            onFocusChange: onFocusChange,
            onTokenInserted: onTokenInserted,
            onTokenRemoved: onTokenRemoved
        )
        context.coordinator.syncFromSwiftUI(tokens: tokens, query: query, force: false)

        if isFocused {
            context.coordinator.focusIfNeeded()
        }

        if let textView = nsView.documentView as? NSTextView {
            let bounds = nsView.contentView.bounds
            if bounds.width > 0, bounds.height > 0 {
                textView.frame = bounds
            }
        }
    }

    @available(macOS 14.0, *)
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSScrollView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? 200
        return CGSize(width: width, height: 24)
    }
}

// MARK: - Coordinator

final class TokenSearchFieldCoordinator: NSObject, NSTextViewDelegate {
    private static let attachmentCharacter = Character("\u{FFFC}")

    @Binding private var tokens: [TokenItem]
    @Binding private var query: String

    private(set) var suggestions: [TokenSuggestion]
    private var onFocusChange: (Bool) -> Void
    private var onTokenInserted: (TokenItem) -> Void
    private var onTokenRemoved: (TokenItem) -> Void

    private weak var textView: TokenTextView?

    private var isSyncingFromSwiftUI = false
    private var lastKnownTokenIDs: [UUID] = []
    private var lastKnownQuery: String = ""
    private var tokenStore: [UUID: TokenItem] = [:]

    init(
        tokens: Binding<[TokenItem]>,
        query: Binding<String>,
        suggestions: [TokenSuggestion],
        onFocusChange: @escaping (Bool) -> Void,
        onTokenInserted: @escaping (TokenItem) -> Void,
        onTokenRemoved: @escaping (TokenItem) -> Void
    ) {
        _tokens = tokens
        _query = query
        self.suggestions = suggestions
        self.onFocusChange = onFocusChange
        self.onTokenInserted = onTokenInserted
        self.onTokenRemoved = onTokenRemoved
    }

    func install(textView: TokenTextView) {
        self.textView = textView
        textView.focusHandler = { [weak self] isFocused in
            self?.onFocusChange(isFocused)
        }
    }

    func update(
        suggestions: [TokenSuggestion],
        onFocusChange: @escaping (Bool) -> Void,
        onTokenInserted: @escaping (TokenItem) -> Void,
        onTokenRemoved: @escaping (TokenItem) -> Void
    ) {
        self.suggestions = suggestions
        self.onFocusChange = onFocusChange
        self.onTokenInserted = onTokenInserted
        self.onTokenRemoved = onTokenRemoved
    }

    func focusIfNeeded() {
        guard let textView, let window = textView.window else { return }
        if window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        }
    }

    func syncFromSwiftUI(tokens: [TokenItem], query: String, force: Bool) {
        guard let textView else { return }

        let tokenIDs = tokens.map { $0.id }
        guard force || tokenIDs != lastKnownTokenIDs || query != lastKnownQuery else {
            return
        }

        isSyncingFromSwiftUI = true
        tokenStore = Dictionary(uniqueKeysWithValues: tokens.map { ($0.id, $0) })

        let attributed = NSMutableAttributedString()
        for token in tokens {
            if let attachment = makeTokenAttachment(for: token) {
                attributed.append(attachment)
                attributed.append(NSAttributedString(string: " "))
            }
        }

        let typingAttributes = textView.typingAttributes
        attributed.append(NSAttributedString(string: query, attributes: typingAttributes))

        textView.textStorage?.setAttributedString(attributed)
        textView.selectedRange = NSRange(location: attributed.length, length: 0)

        lastKnownTokenIDs = tokenIDs
        lastKnownQuery = query
        isSyncingFromSwiftUI = false
    }

    func textDidChange(_ notification: Notification) {
        guard let textView, !isSyncingFromSwiftUI else { return }

        let tokenIDs = extractTokenIDs(from: textView)
        let updatedTokens = tokenIDs.compactMap { tokenStore[$0] }

        if updatedTokens != tokens {
            let removedIDs = Set(lastKnownTokenIDs).subtracting(tokenIDs)
            for id in removedIDs {
                if let removed = tokenStore[id] {
                    onTokenRemoved(removed)
                }
            }
            tokens = updatedTokens
        }

        let nextQuery = normalizedQuery(from: textView.string)
        if nextQuery != query {
            query = nextQuery
        }

        lastKnownTokenIDs = tokenIDs
        lastKnownQuery = nextQuery

        showCompletionsIfNeeded(in: textView)
    }

    func textDidBeginEditing(_ notification: Notification) {
        onFocusChange(true)
    }

    func textDidEndEditing(_ notification: Notification) {
        onFocusChange(false)
    }

    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        if let replacementString, replacementString.contains("\n") {
            return false
        }
        return true
    }

    func textView(
        _ textView: NSTextView,
        doCommandBy selector: Selector
    ) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            if handleInsertTokenIfNeeded(in: textView) {
                return true
            }
            return true
        }

        if selector == #selector(NSResponder.insertTab(_:)) {
            return handleInsertTokenIfNeeded(in: textView)
        }

        return false
    }

    func textView(
        _ textView: NSTextView,
        completions words: [String],
        forPartialWordRange charRange: NSRange,
        indexOfSelectedItem index: UnsafeMutablePointer<Int>?
    ) -> [String] {
        let substring = (textView.string as NSString).substring(with: charRange)
        guard !substring.isEmpty else { return [] }

        let matching = suggestions.filter { suggestion in
            suggestion.label.localizedStandardContains(substring)
        }

        index?.pointee = 0
        return matching.map { $0.label }
    }

    private func handleInsertTokenIfNeeded(in textView: NSTextView) -> Bool {
        guard let range = currentWordRange(in: textView) else { return false }

        let word = (textView.string as NSString).substring(with: range)
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        guard let suggestion = bestSuggestion(for: trimmed) else { return false }

        insertToken(from: suggestion, replacing: range, in: textView)
        return true
    }

    private func insertToken(
        from suggestion: TokenSuggestion,
        replacing range: NSRange,
        in textView: NSTextView
    ) {
        let icon = suggestion.icon
            ?? NSImage(
                systemSymbolName: "tag",
                accessibilityDescription: nil
            )

        guard let icon else { return }

        let token = TokenItem(label: suggestion.label, icon: icon)
        tokenStore[token.id] = token
        onTokenInserted(token)

        let insertion = NSMutableAttributedString()
        if let attachment = makeTokenAttachment(for: token) {
            insertion.append(attachment)
            insertion.append(NSAttributedString(string: " "))
        }

        replaceAttributedText(in: textView, range: range, with: insertion)
    }

    private func replaceAttributedText(
        in textView: NSTextView,
        range: NSRange,
        with attributed: NSAttributedString
    ) {
        guard let textStorage = textView.textStorage else { return }

        textStorage.beginEditing()
        textStorage.replaceCharacters(in: range, with: attributed)
        textStorage.endEditing()

        let location = range.location + attributed.length
        textView.selectedRange = NSRange(location: location, length: 0)
    }

    private func bestSuggestion(for word: String) -> TokenSuggestion? {
        let matches = suggestions.filter { suggestion in
            suggestion.label.localizedStandardContains(word)
        }

        if let exact = matches.first(where: {
            word.compare(
                $0.label,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }) {
            return exact
        }

        let lowered = word.lowercased()
        if let prefix = matches.first(where: {
            $0.label.lowercased().hasPrefix(lowered)
        }) {
            return prefix
        }

        return matches.first
    }

    private func showCompletionsIfNeeded(in textView: NSTextView) {
        guard let range = currentWordRange(in: textView) else { return }
        let word = (textView.string as NSString).substring(with: range)
        guard !word.isEmpty else { return }

        let hasMatch = suggestions.contains { suggestion in
            suggestion.label.localizedStandardContains(word)
        }

        if hasMatch {
            textView.complete(nil)
        }
    }

    private func normalizedQuery(from string: String) -> String {
        string
            .replacing(String(Self.attachmentCharacter), with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTokenIDs(from textView: NSTextView) -> [UUID] {
        guard let storage = textView.textStorage else { return [] }

        var ids: [UUID] = []
        storage.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: storage.length)
        ) { value, _, _ in
            guard let attachment = value as? TokenAttachment else { return }
            ids.append(attachment.tokenID)
        }

        return ids
    }

    private func currentWordRange(in textView: NSTextView) -> NSRange? {
        let selection = textView.selectedRange()
        guard selection.length == 0 else { return nil }

        let text = textView.string as NSString
        if text.length == 0 { return nil }

        var start = selection.location
        var end = selection.location

        while start > 0 {
            let scalar = text.character(at: start - 1)
            if isBoundary(scalar) { break }
            start -= 1
        }

        while end < text.length {
            let scalar = text.character(at: end)
            if isBoundary(scalar) { break }
            end += 1
        }

        guard end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private func isBoundary(_ scalar: unichar) -> Bool {
        if scalar == unichar(Self.attachmentCharacter.unicodeScalars.first?.value ?? 0) {
            return true
        }
        guard let unicode = UnicodeScalar(scalar) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(unicode)
    }

    private func makeTokenAttachment(for token: TokenItem) -> NSAttributedString? {
        let attachment = TokenAttachment(tokenID: token.id, label: token.label, icon: token.icon)
        return NSAttributedString(attachment: attachment)
    }
}

// MARK: - TokenTextView

final class TokenTextView: NSTextView {
    var focusHandler: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            focusHandler?(true)
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            focusHandler?(false)
        }
        return result
    }
}

// MARK: - TokenAttachment

private final class TokenAttachment: NSTextAttachment {
    let tokenID: UUID

    init(tokenID: UUID, label: String, icon: NSImage) {
        self.tokenID = tokenID
        super.init(data: nil, ofType: nil)
        attachmentCell = TokenAttachmentCell(label: label, icon: icon)
    }

    nonisolated override init(data: Data?, ofType uti: String?) {
        self.tokenID = UUID()
        super.init(data: data, ofType: uti)
    }

    @available(*, unavailable)
    required nonisolated init?(coder: NSCoder) {
        nil
    }

    nonisolated override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: NSRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> NSRect {
        guard let cell = attachmentCell else { return .zero }
        let size = cell.cellSize()
        let y = lineFrag.origin.y + (lineFrag.height - size.height) / 2
        return NSRect(x: 0, y: y, width: size.width, height: size.height)
    }
}

private final class TokenAttachmentCell: NSTextAttachmentCell {
    private let label: String
    private let icon: NSImage

    private let paddingX: CGFloat = 8
    private let paddingY: CGFloat = 4
    private let iconSize: CGFloat = 14
    private let cornerRadius: CGFloat = 12

    init(label: String, icon: NSImage) {
        self.label = label
        self.icon = icon
        super.init(textCell: "")
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        self.label = ""
        self.icon = NSImage()
        super.init(coder: coder)
        fatalError("init(coder:) is not supported")
    }

    nonisolated override func cellSize() -> NSSize {
        MainActor.assumeIsolated {
            let textSize = labelSize()
            let width = paddingX * 2 + iconSize + 4 + textSize.width
            let height = max(textSize.height, iconSize) + paddingY * 2
            return NSSize(width: width, height: height)
        }
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        let path = NSBezierPath(
            roundedRect: cellFrame,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )
        let fill = NSColor.textBackgroundColor.withAlphaComponent(0.9)
        fill.setFill()
        path.fill()

        let border = NSColor.separatorColor.withAlphaComponent(0.55)
        border.setStroke()
        path.lineWidth = 1
        path.stroke()

        let iconRect = NSRect(
            x: cellFrame.minX + paddingX,
            y: cellFrame.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        icon.draw(in: iconRect)

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.preferredFont(forTextStyle: .callout),
            .foregroundColor: NSColor.labelColor,
        ]

        let textOrigin = NSPoint(
            x: iconRect.maxX + 4,
            y: cellFrame.midY - labelSize().height / 2
        )
        label.draw(at: textOrigin, withAttributes: textAttributes)
    }

    private func labelSize() -> NSSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.preferredFont(forTextStyle: .callout),
        ]
        return (label as NSString).size(withAttributes: attributes)
    }
}

extension TokenSearchField {
    typealias Coordinator = TokenSearchFieldCoordinator
}
