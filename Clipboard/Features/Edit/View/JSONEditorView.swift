//
//  JSONEditorView.swift
//  Clipboard
//

import AppKit
import SnapKit

final class JSONEditorView: NSView {
    private static let githubLightKey = NSColor(hex: "#116329")
    private static let githubLightString = NSColor(hex: "#0A3069")
    private static let githubLightNumber = NSColor(hex: "#0550AE")
    private static let githubLightLiteral = NSColor(hex: "#CF222E")
    private static let githubLightPunctuation = NSColor(hex: "#57606A")

    private static let githubDarkKey = NSColor(hex: "#7EE787")
    private static let githubDarkString = NSColor(hex: "#A5D6FF")
    private static let githubDarkNumber = NSColor(hex: "#79C0FF")
    private static let githubDarkLiteral = NSColor(hex: "#FF7B72")
    private static let githubDarkPunctuation = NSColor(hex: "#8B949E")

    // MARK: - Callbacks

    var onTextChange: (() -> Void)?
    var onCursorChange: ((Int, Int) -> Void)?

    // MARK: - Public

    var indentation = JSONIndentation.four

    var currentText: String {
        textView.string
    }

    var isBusy = false

    // MARK: - Text System

    private let scrollView: NSScrollView
    private let textView: NSTextView
    private let lineIndex = JSONLineIndex()
    private lazy var lineRuler = JSONLineNumberRulerView(
        textView: textView,
        lineIndex: lineIndex
    )

    // MARK: - Tasks

    private var lineTask: Task<Void, Never>?
    private var lineNumberTask: Task<Void, Never>?
    private var highlightTask: Task<Void, Never>?
    private var highlightRequestID = 0
    private var highlightWorkerID = 0
    private var generation = 0
    private var lineNumberViewportSize = NSSize.zero
    private var highlightedRange = NSRange(location: 0, length: 0)
    private var reportedSelection = NSRange(location: NSNotFound, length: 0)
    private var pendingEdit: (range: NSRange, replacement: String)?
    private var lineIndexRevision = 0
    private var reportedLineIndexRevision = -1
    private var shouldRebuildLineIndex = false
    private var suppressChanges = false
    private var isLineIndexReady = false

    private var baseTextAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ]
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

    deinit {
        lineTask?.cancel()
        lineNumberTask?.cancel()
        highlightTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setup() {
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.importsGraphics = false
        textView.allowsImageEditing = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.usesFindBar = true

        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.typingAttributes = baseTextAttributes
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 10, height: 8)
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.delegate = self
        textView.textStorage?.delegate = self

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalRuler = false
        scrollView.rulersVisible = false
        scrollView.contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScroll),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        addSubview(lineRuler)
        addSubview(scrollView)
        lineRuler.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
        }
        scrollView.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
            make.leading.equalTo(lineRuler.snp.trailing)
        }
    }

    override func layout() {
        super.layout()

        let viewportSize = scrollView.contentView.bounds.size
        guard viewportSize.width > 0,
              viewportSize.height > 0,
              viewportSize != lineNumberViewportSize
        else { return }

        lineNumberViewportSize = viewportSize
        scheduleLineNumberRefresh(immediately: true)
    }

    // MARK: - Content

    func setText(_ text: String, lineStarts: [Int]? = nil) {
        lineTask?.cancel()
        lineNumberTask?.cancel()
        cancelHighlight()
        pendingEdit = nil
        if highlightedRange.length > 0,
           let layoutManager = textView.layoutManager
        {
            let currentRange = NSRange(
                location: 0,
                length: textView.string.utf16.count
            )
            let removableRange = NSIntersectionRange(highlightedRange, currentRange)
            if removableRange.length > 0 {
                layoutManager.removeTemporaryAttribute(
                    .foregroundColor,
                    forCharacterRange: removableRange
                )
            }
        }
        highlightedRange = NSRange(location: 0, length: 0)
        suppressChanges = true
        textView.undoManager?.disableUndoRegistration()
        textView.typingAttributes = baseTextAttributes
        textView.string = text
        textView.typingAttributes = baseTextAttributes
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.undoManager?.enableUndoRegistration()
        textView.undoManager?.removeAllActions()
        suppressChanges = false
        generation += 1
        if let lineStarts {
            lineIndex.replace(with: lineStarts)
            lineIndexRevision &+= 1
            isLineIndexReady = true
            updateCursor()
        } else {
            rebuildLineIndex(for: text, generation: generation)
        }
        invalidateTextDisplay()
        scheduleHighlight()
    }

    func transformTarget() -> (text: String, range: NSRange) {
        let selection = textView.selectedRange()
        let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
        let range = selection.length > 0 ? selection : fullRange
        let text = (textView.string as NSString).substring(with: range)
        return (text, range)
    }

    @discardableResult
    func replaceText(_ text: String, in range: NSRange) -> Bool {
        let source = textView.string as NSString
        guard range.location <= source.length,
              NSMaxRange(range) <= source.length
        else { return false }

        let previousText = source.substring(with: range)
        guard previousText != text,
              let textStorage = textView.textStorage
        else { return false }

        let originalSelection = textView.selectedRange()
        let clipView = scrollView.contentView
        let visibleOrigin = clipView.bounds.origin
        let replacementLength = text.utf16.count
        let restoredSelection = selectionAfterReplacing(
            range,
            withLength: replacementLength,
            originalSelection: originalSelection
        )

        window?.disableScreenUpdatesUntilFlush()
        cancelHighlight()
        suppressChanges = true
        let replacement = NSAttributedString(
            string: text,
            attributes: baseTextAttributes
        )
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: range, with: replacement)
        textStorage.endEditing()
        suppressChanges = false

        textView.undoManager?.registerUndo(withTarget: self) { target in
            target.replaceText(
                previousText,
                in: NSRange(location: range.location, length: replacementLength)
            )
        }

        generation += 1
        pendingEdit = nil
        shouldRebuildLineIndex = false
        rebuildLineIndex(for: textView.string, generation: generation)
        textView.setSelectedRange(restoredSelection)
        var targetBounds = clipView.bounds
        targetBounds.origin = visibleOrigin
        let constrainedBounds = clipView.constrainBoundsRect(targetBounds)
        clipView.scroll(to: constrainedBounds.origin)
        scrollView.reflectScrolledClipView(clipView)
        invalidateTextDisplay()
        scheduleHighlight()
        onTextChange?()
        window?.contentView?.needsDisplay = true
        return true
    }

    func focus(revealingSelection: Bool = true) {
        window?.makeFirstResponder(textView)
        if revealingSelection {
            textView.scrollRangeToVisible(textView.selectedRange())
        }
        invalidateTextDisplay()
        scheduleHighlight()
    }

    /// 直接重置 clip view，不触发选区定位或全文布局。
    func scrollToTop() {
        let clipView = scrollView.contentView
        var targetBounds = clipView.bounds
        targetBounds.origin = .zero
        let constrainedBounds = clipView.constrainBoundsRect(targetBounds)
        clipView.scroll(to: constrainedBounds.origin)
        scrollView.reflectScrolledClipView(clipView)
    }

    private func selectionAfterReplacing(
        _ replacedRange: NSRange,
        withLength replacementLength: Int,
        originalSelection: NSRange
    ) -> NSRange {
        if originalSelection == replacedRange, originalSelection.length > 0 {
            return NSRange(location: replacedRange.location, length: replacementLength)
        }

        if NSMaxRange(originalSelection) <= replacedRange.location {
            return originalSelection
        }

        if originalSelection.location >= NSMaxRange(replacedRange) {
            let delta = replacementLength - replacedRange.length
            return NSRange(
                location: max(0, originalSelection.location + delta),
                length: originalSelection.length
            )
        }

        guard originalSelection.length == 0, replacedRange.length > 0 else {
            return NSRange(location: replacedRange.location, length: replacementLength)
        }

        let relativeLocation = originalSelection.location - replacedRange.location
        let progress = Double(relativeLocation) / Double(replacedRange.length)
        let mappedLocation = Int((progress * Double(replacementLength)).rounded())
        return NSRange(
            location: replacedRange.location + min(mappedLocation, replacementLength),
            length: 0
        )
    }

    private func invalidateTextDisplay() {
        let range = NSRange(location: 0, length: textView.string.utf16.count)
        if range.length > 0 {
            textView.layoutManager?.invalidateDisplay(forCharacterRange: range)
        }
        textView.needsDisplay = true
    }

    // MARK: - Line Index

    private func rebuildLineIndex(for text: String, generation: Int) {
        isLineIndexReady = false
        lineTask?.cancel()
        lineNumberTask?.cancel()
        lineRuler.clearVisibleLines()
        lineTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .utility) {
                JSONLineIndex.build(for: text)
            }
            let starts = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard let self,
                  !Task.isCancelled,
                  generation == self.generation
            else { return }

            lineIndex.replace(with: starts)
            lineIndexRevision &+= 1
            isLineIndexReady = true
            updateCursor()
        }
    }

    private func updateLineIndexAfterTextChange() {
        if shouldRebuildLineIndex {
            shouldRebuildLineIndex = false
            rebuildLineIndex(for: textView.string, generation: generation)
            return
        }

        guard isLineIndexReady else {
            rebuildLineIndex(for: textView.string, generation: generation)
            return
        }

        if textView.selectedRange() != reportedSelection
            || lineIndexRevision != reportedLineIndexRevision
        {
            updateCursor()
        }
    }

    private func updateCursor() {
        let selection = textView.selectedRange()
        reportedSelection = selection
        reportedLineIndexRevision = lineIndexRevision
        let location = min(selection.location, textView.string.utf16.count)
        let position = lineIndex.lineAndColumn(at: location)
        lineRuler.update(lineCount: lineIndex.lineCount, currentLine: position.line)
        onCursorChange?(position.line, position.column)
        scheduleLineNumberRefresh()
    }

    private func scheduleLineNumberRefresh(immediately: Bool = false) {
        lineNumberTask?.cancel()
        lineNumberTask = Task { @MainActor [weak self] in
            if immediately {
                await Task.yield()
            } else {
                try? await Task.sleep(for: .milliseconds(16))
            }
            guard let self,
                  !Task.isCancelled,
                  isLineIndexReady,
                  !isHidden
            else { return }

            lineRuler.refreshVisibleLines()
        }
    }

    // MARK: - Highlighting

    @objc private func handleScroll() {
        scheduleHighlight()
        scheduleLineNumberRefresh(immediately: true)
    }

    private func cancelHighlight() {
        highlightRequestID &+= 1
        highlightWorkerID &+= 1
        highlightTask?.cancel()
        highlightTask = nil
    }

    private func scheduleHighlight() {
        highlightRequestID &+= 1
        guard highlightTask == nil else { return }

        highlightWorkerID &+= 1
        let workerID = highlightWorkerID
        highlightTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if workerID == highlightWorkerID {
                    highlightTask = nil
                }
            }

            while !Task.isCancelled {
                let requestID = highlightRequestID
                let generation = generation
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
                guard requestID == highlightRequestID,
                      generation == self.generation
                else { continue }
                guard let range = highlightScanRange() else { return }

                let source = textView.string as NSString
                let segment = source.substring(with: range)
                let worker = Task.detached(priority: .utility) {
                    JSONSyntaxHighlighter.spans(in: segment, offset: range.location)
                }
                let spans = await withTaskCancellationHandler {
                    await worker.value
                } onCancel: {
                    worker.cancel()
                }

                guard !Task.isCancelled else { return }
                guard requestID == highlightRequestID,
                      generation == self.generation
                else { continue }
                guard let layoutManager = textView.layoutManager else { return }

                let textLength = textView.string.utf16.count
                let currentRange = NSRange(location: 0, length: textLength)
                let removableRange = NSIntersectionRange(highlightedRange, currentRange)
                if removableRange.length > 0 {
                    layoutManager.removeTemporaryAttribute(
                        .foregroundColor,
                        forCharacterRange: removableRange
                    )
                }

                for span in spans where NSMaxRange(span.range) <= textLength {
                    layoutManager.addTemporaryAttribute(
                        .foregroundColor,
                        value: color(for: span.kind),
                        forCharacterRange: span.range
                    )
                }
                highlightedRange = range
                return
            }
        }
    }

    private func highlightScanRange() -> NSRange? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return nil }

        let textLength = textView.string.utf16.count
        guard textLength > 0 else { return nil }

        let origin = textView.textContainerOrigin
        let visibleRect = textView.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let glyphRange = layoutManager.glyphRange(
            forBoundingRect: visibleRect,
            in: textContainer
        )
        let visibleCharacters = layoutManager.characterRange(
            forGlyphRange: glyphRange,
            actualGlyphRange: nil
        )
        let lookaround = 32768
        let start = max(0, visibleCharacters.location - lookaround)
        let end = min(textLength, NSMaxRange(visibleCharacters) + lookaround)
        return NSRange(location: start, length: max(0, end - start))
    }

    private func color(for kind: JSONSyntaxHighlighter.Kind) -> NSColor {
        let isDark = effectiveAppearance.bestMatch(
            from: [.darkAqua, .aqua]
        ) == .darkAqua
        return switch kind {
        case .key: isDark ? Self.githubDarkKey : Self.githubLightKey
        case .string: isDark ? Self.githubDarkString : Self.githubLightString
        case .number: isDark ? Self.githubDarkNumber : Self.githubLightNumber
        case .literal: isDark ? Self.githubDarkLiteral : Self.githubLightLiteral
        case .punctuation:
            isDark ? Self.githubDarkPunctuation : Self.githubLightPunctuation
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        scheduleHighlight()
        lineRuler.needsDisplay = true
    }

    // MARK: - Editing Commands

    private func insertIndent() {
        let spaces = String(repeating: " ", count: indentation.rawValue)
        textView.insertText(spaces, replacementRange: textView.selectedRange())
    }

    private func insertNewline() {
        let source = textView.string as NSString
        let location = textView.selectedRange().location
        let lineRange = source.lineRange(for: NSRange(location: location, length: 0))
        let prefixRange = NSRange(
            location: lineRange.location,
            length: max(0, location - lineRange.location)
        )
        let prefix = source.substring(with: prefixRange)
        let leading = prefix.prefix(while: { $0 == " " || $0 == "\t" })
        let trimmed = prefix.trimmingCharacters(in: .whitespaces)
        let extra = trimmed.last == "{" || trimmed.last == "["
            ? String(repeating: " ", count: indentation.rawValue)
            : ""
        textView.insertText(
            "\n" + leading + extra,
            replacementRange: textView.selectedRange()
        )
    }
}

// MARK: - NSTextViewDelegate

extension JSONEditorView: NSTextViewDelegate {
    func textView(
        _: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        guard !isBusy else { return false }
        pendingEdit = replacementString.map {
            (range: affectedCharRange, replacement: $0)
        }
        return true
    }

    func textDidChange(_: Notification) {
        guard !suppressChanges else { return }
        generation += 1
        updateLineIndexAfterTextChange()
        scheduleHighlight()
        onTextChange?()
    }

    func textViewDidChangeSelection(_: Notification) {
        guard isLineIndexReady,
              textView.selectedRange() != reportedSelection
                || lineIndexRevision != reportedLineIndexRevision
        else { return }
        updateCursor()
    }

    func textView(_: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertTab(_:)):
            insertIndent()
            return true
        case #selector(NSResponder.insertNewline(_:)):
            insertNewline()
            return true
        default:
            return false
        }
    }
}

// MARK: - NSTextStorageDelegate

extension JSONEditorView: NSTextStorageDelegate {
    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range _: NSRange,
        changeInLength delta: Int
    ) {
        guard !suppressChanges,
              editedMask.contains(.editedCharacters)
        else { return }

        let edit: (range: NSRange, replacement: String)?
        if let pendingEdit,
           pendingEdit.replacement.utf16.count - pendingEdit.range.length == delta
        {
            edit = pendingEdit
        } else {
            let markedRange = textView.markedRange()
            let replacedRange = markedRange.location == NSNotFound
                ? textView.selectedRange()
                : markedRange
            let replacementLength = replacedRange.length + delta
            guard delta != 0,
                  replacementLength >= 0
            else {
                self.pendingEdit = nil
                return
            }

            let replacementRange = NSRange(
                location: replacedRange.location,
                length: replacementLength
            )
            guard replacementRange.location <= textStorage.length,
                  NSMaxRange(replacementRange) <= textStorage.length
            else {
                self.pendingEdit = nil
                shouldRebuildLineIndex = true
                return
            }

            edit = (
                range: replacedRange,
                replacement: textStorage.attributedSubstring(from: replacementRange).string
            )
        }
        self.pendingEdit = nil

        guard let edit else { return }
        guard isLineIndexReady,
              edit.range.location <= textStorage.length,
              max(edit.range.length, edit.replacement.utf16.count) <= 65536
        else {
            shouldRebuildLineIndex = true
            return
        }

        lineIndex.applyReplacement(
            range: edit.range,
            replacement: edit.replacement
        )
        lineIndexRevision &+= 1
    }
}
