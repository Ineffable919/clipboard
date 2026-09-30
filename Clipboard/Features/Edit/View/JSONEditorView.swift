//
//  JSONEditorView.swift
//  Clipboard
//

import AppKit
import SnapKit

final class JSONEditorView: NSView {
    private static let lightString = NSColor(hex: "#008000")
    private static let lightNumber = NSColor(hex: "#3322FF")
    private static let lightLiteral = NSColor(hex: "#B333B3")

    private static let darkString = NSColor(hex: "#7ECF87")
    private static let darkNumber = NSColor(hex: "#8FA8FF")
    private static let darkLiteral = NSColor(hex: "#D99BE5")

    // MARK: - Callbacks

    var onTextChange: ((Int?) -> Void)?
    var onCursorChange: ((Int, Int) -> Void)?
    var onBusyChange: ((Bool) -> Void)?

    // MARK: - Public

    var indentation = JSONIndentation.four {
        didSet { viewport?.indentation = indentation }
    }
    var knownValidity: Bool?

    var currentText: String {
        viewport?.currentText ?? foldedSource ?? textView.string
    }

    var isBusy = false {
        didSet {
            textView.isEditable = !isBusy
            viewport?.isEditable = !isBusy
            onBusyChange?(isBusy)
        }
    }

    var preparationWidth: CGFloat {
        max(100, scrollView.contentView.bounds.width - textView.textContainerInset.width * 2)
    }

    // MARK: - Text System

    private let scrollView: NSScrollView
    private var textView: JSONTextView
    private let lineIndex = JSONLineIndex()
    private lazy var lineRuler = JSONLineNumberRulerView(
        textView: textView,
        lineIndex: lineIndex
    )

    // MARK: - Tasks

    private var lineTask: Task<Void, Never>?
    private var lineNumberTask: Task<Void, Never>?
    private var highlightTask: Task<Void, Never>?
    private var foldTask: Task<Void, Never>?
    private var restoreTask: Task<Void, Never>?
    private var scrollTask: Task<Void, Never>?
    private var foldRequestID = 0
    private var folds = JSONFoldProjection()
    private var foldedSource: String?
    private var preparedText: JSONPreparedText?
    private var viewport: JSONViewportEditor?
    private var highlightRequestID = 0
    private var highlightWorkerID = 0
    private var generation = 0
    private var lineNumberViewportSize = NSSize.zero
    private var editorSize = NSSize.zero
    private var highlightedRange = NSRange(location: 0, length: 0)
    private var highlightedGeneration = -1
    private var reportedSelection = NSRange(location: NSNotFound, length: 0)
    private var pendingEdit: (range: NSRange, replacement: String)?
    private var lineIndexRevision = 0
    private var reportedLineIndexRevision = -1
    private var shouldRebuildLineIndex = false
    private var suppressChanges = false
    private var isLineIndexReady = false
    private var isClosed = false

    private var baseTextAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ]
    }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        let scroll = JSONTextView.scrollableTextView()
        let text = (scroll.documentView as? JSONTextView) ?? JSONTextView()
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
        foldTask?.cancel()
        restoreTask?.cancel()
        scrollTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    func cancelWork() {
        isClosed = true
        viewport?.cancelWork()
        lineTask?.cancel()
        lineNumberTask?.cancel()
        cancelHighlight()
        foldTask?.cancel()
        restoreTask?.cancel()
        scrollTask?.cancel()
        textView.undoManager?.removeAllActions()
    }

    // MARK: - Setup

    private func configureTextView() {
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

        if textView.textStorage?.length == 0 {
            textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
            textView.textColor = .labelColor
        }
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
        textView.minSize = NSSize(width: 0, height: scrollView.contentView.bounds.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = .width
        textView.layoutManager?.allowsNonContiguousLayout = true
        // 仅布局可见范围，避免空闲时排版整个大文档
        textView.layoutManager?.backgroundLayoutEnabled = false
        if !(textView.layoutManager?.typesetter is JSONTypesetter) {
            textView.layoutManager?.typesetter = JSONTypesetter()
        }
        textView.delegate = self
        textView.textStorage?.delegate = self
    }

    private func setup() {
        configureTextView()
        setupFolding()

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

        let resized = bounds.size != editorSize
        let viewportSize = scrollView.contentView.bounds.size
        guard viewportSize.width > 0,
              viewportSize.height > 0,
              viewportSize != lineNumberViewportSize
        else { return }

        lineNumberViewportSize = viewportSize
        editorSize = bounds.size
        scheduleLineNumberRefresh(immediately: true)
        if viewport == nil, resized {
            scrollTask?.cancel()
            scrollTask = Task { @MainActor [weak self] in
                await Task.yield()
                guard let self, !Task.isCancelled, !isClosed else { return }
                textView.setSelectedRange(NSRange(location: 0, length: 0))
                scrollToTop()
            }
        }
    }

    // MARK: - Content

    func setText(
        _ text: String,
        document: JSONFoldIndex.Document? = nil,
        preparedText: JSONPreparedText? = nil,
        resettingUndo: Bool = true
    ) {
        if let preparedText {
            installViewport(text, document: document, prepared: preparedText)
            return
        }
        viewport?.removeFromSuperview()
        viewport = nil
        scrollView.isHidden = false
        lineRuler.isHidden = false
        foldedSource = nil
        folds.reset()
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
        if resettingUndo { textView.undoManager?.removeAllActions() }
        suppressChanges = false
        generation += 1
        if let document {
            lineIndex.replace(with: document.lineStarts)
            lineIndexRevision &+= 1
            isLineIndexReady = true
            updateCursor()
        } else {
            rebuildLineIndex(for: text, generation: generation)
        }
        invalidateTextDisplay()
        scheduleHighlight()
        if let document {
            foldTask?.cancel()
            foldRequestID &+= 1
            folds.reset(nodes: document.nodes)
            scheduleLineNumberRefresh(immediately: true)
        } else {
            scheduleFoldIndex(immediately: true, source: text)
        }
    }

    func transformTarget() -> (text: String, range: NSRange) {
        let selection = viewport?.selection ?? folds.sourceRange(for: textView.selectedRange())
        let source = currentText as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let range = selection.length > 0 ? selection : fullRange
        let text = range == fullRange ? currentText : source.substring(with: range)
        return (text, range)
    }

    @discardableResult
    func replaceText(
        _ text: String,
        in range: NSRange,
        document: JSONFoldIndex.Document? = nil,
        previousText preparedPreviousText: String? = nil,
        preparedText: JSONPreparedText? = nil,
        knownValidity: Bool? = nil,
        registeringUndo: Bool = true
    ) -> Bool {
        let source = currentText as NSString
        guard range.location <= source.length,
              NSMaxRange(range) <= source.length
        else { return false }

        let previousText = preparedPreviousText ?? source.substring(with: range)
        let previousValidity = self.knownValidity
        let entireDocument = range.location == 0 && range.length == source.length
        let replacementValidity = entireDocument ? knownValidity : nil
        if viewport != nil || preparedText != nil {
            return replaceViewport(
                text, replacement: JSONViewportReplacement(
                    range: range, entireDocument: entireDocument, index: document, prepared: preparedText,
                    previousText: previousText, previousValidity: previousValidity,
                    validity: replacementValidity, registeringUndo: registeringUndo
                ), viewport: viewport
            )
        }
        guard preparedPreviousText != nil || !(previousText as NSString).isEqual(to: text),
              let textStorage = textView.textStorage
        else { return false }

        expandFolds()
        let clipView = scrollView.contentView
        let visibleOrigin = NSPoint.zero
        let replacementLength = text.utf16.count

        window?.disableScreenUpdatesUntilFlush()
        cancelHighlight()
        suppressChanges = true
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: range, with: text)
        textStorage.setAttributes(
            baseTextAttributes,
            range: NSRange(location: range.location, length: replacementLength)
        )
        textStorage.endEditing()
        suppressChanges = false

        if registeringUndo {
            textView.undoManager?.registerUndo(withTarget: self) { target in
                if entireDocument, max(range.length, replacementLength) >= 1_048_576 {
                    target.restoreDocument(
                        previousText, validity: previousValidity,
                        reversing: text, oppositeValidity: replacementValidity
                    )
                } else {
                    target.replaceText(
                        previousText,
                        in: NSRange(location: range.location, length: replacementLength),
                        knownValidity: previousValidity
                    )
                }
            }
        }

        if let document {
            generation &+= 1
            lineTask?.cancel()
            foldTask?.cancel()
            foldRequestID &+= 1
            pendingEdit = nil
            shouldRebuildLineIndex = false
            lineIndex.replace(with: document.lineStarts)
            lineIndexRevision &+= 1
            isLineIndexReady = true
            folds.reset(nodes: document.nodes)
        } else {
            rebuildIndexesAfterReplacement()
        }
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        var targetBounds = clipView.bounds
        targetBounds.origin = visibleOrigin
        let constrainedBounds = clipView.constrainBoundsRect(targetBounds)
        clipView.scroll(to: constrainedBounds.origin)
        scrollView.reflectScrolledClipView(clipView)
        invalidateTextDisplay()
        scheduleHighlight()
        self.knownValidity = replacementValidity
        onTextChange?(document?.statisticsLineCount)
        window?.contentView?.needsDisplay = true
        return true
    }

    func restoreDocument(
        _ text: String, validity: Bool?, reversing opposite: String, oppositeValidity: Bool?
    ) {
        // 在 UndoManager 的撤销回调中立即登记反向操作，计算与显示可稍后完成
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreDocument(opposite, validity: oppositeValidity, reversing: text, oppositeValidity: validity)
        }
        restoreTask?.cancel()
        isBusy = true
        let width = preparationWidth
        restoreTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                JSONDocument.prepare(text, knownValidity: validity, width: width)
            }
            let document = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard let self, !Task.isCancelled else { return }
            defer { isBusy = false }
            replaceText(
                document.text, in: NSRange(location: 0, length: (currentText as NSString).length),
                document: document.index, previousText: opposite,
                preparedText: document.preparedText, knownValidity: document.isValid, registeringUndo: false
            )
        }
    }

    func focus(revealingSelection: Bool = true) {
        if let viewport { viewport.focus(); return }
        window?.makeFirstResponder(textView)
        if revealingSelection {
            textView.scrollRangeToVisible(textView.selectedRange())
        }
        invalidateTextDisplay()
        scheduleHighlight()
    }

    private func installViewport(_ text: String, document: JSONFoldIndex.Document?, prepared: JSONPreparedText) {
        cancelHighlight()
        lineTask?.cancel()
        lineNumberTask?.cancel()
        foldTask?.cancel()
        scrollView.isHidden = true
        lineRuler.isHidden = true
        if viewport == nil {
            viewport = makeViewport()
        }
        layoutSubtreeIfNeeded()
        viewport?.setText(text, document: document, prepared: prepared)
        viewport?.focus()
    }

    /// 首屏排版稳定后重置滚动位置，避免长文档后续调整高度时偏离顶部
    func scrollToTop() {
        if let viewport { viewport.scrollToTop(); return }
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        layoutSubtreeIfNeeded()
        let clipView = scrollView.contentView
        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            layoutManager.ensureLayout(
                forBoundingRect: NSRect(origin: .zero, size: clipView.bounds.size),
                in: textContainer
            )
            textView.sizeToFit()
        }
        var targetBounds = clipView.bounds
        targetBounds.origin = .zero
        let constrainedBounds = clipView.constrainBoundsRect(targetBounds)
        clipView.scroll(to: constrainedBounds.origin)
        scrollView.reflectScrolledClipView(clipView)
    }

    private func invalidateTextDisplay() {
        let range = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
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
        let location = folds.sourceLocation(for: selection.location)
        let position = lineIndex.lineAndColumn(at: location)
        lineRuler.update(lineCount: lineIndex.lineCount, currentLine: position.line)
        onCursorChange?(position.line, position.column)
        scheduleLineNumberRefresh()
    }

    private func scheduleLineNumberRefresh(immediately: Bool = false) {
        guard !isClosed else { return }
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
        guard viewport == nil else { return }
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
        guard !isClosed else { return }
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
                guard let range = highlightScanRange(),
                      let storage = textView.textStorage else { return }
                let segment = storage.mutableString.substring(with: range)
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
                applyHighlight(spans, in: range)
                return
            }
        }
    }

    private func applyHighlight(_ spans: [JSONSyntaxHighlighter.Span], in range: NSRange) {
        guard let layoutManager = textView.layoutManager,
              let storage = textView.textStorage else { return }
        let removableRange = NSIntersectionRange(highlightedRange, NSRange(location: 0, length: storage.length))
        if removableRange.length > 0 {
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: removableRange)
        }
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let colors: [JSONSyntaxHighlighter.Kind: NSColor] = [
            .string: isDark ? Self.darkString : Self.lightString,
            .number: isDark ? Self.darkNumber : Self.lightNumber,
            .literal: isDark ? Self.darkLiteral : Self.lightLiteral
        ]
        for span in spans where NSMaxRange(span.range) <= storage.length {
            // 键和标点沿用正文色，避免为每个标点维护临时属性
            guard let color = colors[span.kind] else { continue }
            layoutManager.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: span.range)
        }
        highlightedRange = range
        highlightedGeneration = generation
    }

    private func highlightScanRange() -> NSRange? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return nil }

        let textLength = textView.textStorage?.length ?? 0
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
        if highlightedGeneration == generation,
           NSIntersectionRange(highlightedRange, visibleCharacters) == visibleCharacters {
            return nil
        }
        let lookaround = 32768
        let start = max(0, visibleCharacters.location - lookaround)
        let end = min(textLength, NSMaxRange(visibleCharacters) + lookaround)
        return NSRange(location: start, length: max(0, end - start))
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        highlightedGeneration = -1
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

// MARK: - Folding

private extension JSONEditorView {
    func setupFolding() {
        textView.onPrepareEdit = { [weak self] range in
            self?.prepareEdit(in: range) ?? range
        }
        textView.onExpand = { [weak self] in self?.expandFolds() }
        textView.onCopy = { [weak self] range in
            guard let self else { return "" }
            return (currentText as NSString).substring(with: folds.sourceRange(for: range))
        }
        lineRuler.sourceLocation = { [weak self] location in
            self?.folds.sourceLocation(for: location) ?? location
        }
        lineRuler.foldAtLine = { [weak self] location in
            guard let self, let node = folds.node(atLineStart: location) else { return nil }
            return (node, folds.collapsed.contains(node))
        }
        lineRuler.onToggleFold = { [weak self] node in self?.toggleFold(node) }
        for name in [Notification.Name.NSUndoManagerWillUndoChange, .NSUndoManagerWillRedoChange] {
            NotificationCenter.default.addObserver(self, selector: #selector(prepareUndo(_:)), name: name, object: nil)
        }
    }

    func rebuildIndexesAfterReplacement() {
        generation += 1
        pendingEdit = nil
        shouldRebuildLineIndex = false
        rebuildLineIndex(for: textView.string, generation: generation)
        scheduleFoldIndex(immediately: true)
    }

    func scheduleFoldIndex(immediately: Bool = false, source initialSource: String? = nil) {
        foldTask?.cancel()
        foldRequestID &+= 1
        let requestID = foldRequestID
        folds.reset()
        scheduleLineNumberRefresh(immediately: true)
        foldTask = Task { @MainActor [weak self] in
            if !immediately {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard let self, !Task.isCancelled else { return }
            let source = initialSource ?? currentText
            let worker = Task.detached(priority: .utility) {
                JSONFoldIndex.build(for: source)
            }
            let nodes = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled, requestID == foldRequestID else { return }
            folds.reset(nodes: nodes)
            scheduleLineNumberRefresh(immediately: true)
        }
    }

    func toggleFold(_ node: Int) {
        guard !isBusy, !textView.hasMarkedText(), folds.nodes.indices.contains(node) else { return }
        let body = folds.nodes[node].body
        let displayRange = folds.displayRange(for: body)
        let selection = folds.sourceRange(for: textView.selectedRange())
        if foldedSource == nil {
            foldedSource = textView.string
        }
        let source = currentText as NSString
        folds.toggle(node)
        let replacement = folds.text(in: source, range: body)
        updateFoldDisplay(selection: folds.displayRange(for: selection)) { storage in
            storage.replaceCharacters(in: displayRange, with: replacement)
            storage.setAttributes(
                baseTextAttributes,
                range: NSRange(location: displayRange.location, length: replacement.utf16.count)
            )
        }
        if folds.collapsed.isEmpty {
            foldedSource = nil
        }
    }

    func expandFolds() {
        guard let foldedSource else { return }
        let source = foldedSource as NSString
        let segments = folds.segments
        let selection = folds.sourceRange(for: textView.selectedRange())
        folds.reset(nodes: folds.nodes)
        updateFoldDisplay(selection: selection) { storage in
            for segment in segments.reversed() {
                storage.replaceCharacters(in: segment.display, with: source.substring(with: segment.source))
                storage.setAttributes(
                    baseTextAttributes,
                    range: NSRange(location: segment.display.location, length: segment.source.length)
                )
            }
        }
        self.foldedSource = nil
    }

    func updateFoldDisplay(selection: NSRange, edit: (NSTextStorage) -> Void) {
        guard let storage = textView.textStorage else { return }
        let clipView = scrollView.contentView
        let origin = clipView.bounds.origin
        window?.disableScreenUpdatesUntilFlush()
        cancelHighlight()
        let highlighted = NSIntersectionRange(highlightedRange, NSRange(location: 0, length: storage.length))
        if highlighted.length > 0 {
            textView.layoutManager?.removeTemporaryAttribute(.foregroundColor, forCharacterRange: highlighted)
        }
        highlightedRange = NSRange(location: 0, length: 0)
        suppressChanges = true
        storage.beginEditing()
        edit(storage)
        storage.endEditing()
        textView.setSelectedRange(selection)
        suppressChanges = false
        generation &+= 1
        var bounds = clipView.bounds
        bounds.origin = origin
        clipView.scroll(to: clipView.constrainBoundsRect(bounds).origin)
        scrollView.reflectScrolledClipView(clipView)
        updateCursor()
        scheduleLineNumberRefresh(immediately: true)
        scheduleHighlight()
    }

    func prepareEdit(in range: NSRange) -> NSRange {
        guard foldedSource != nil else { return range }
        let displayRange = range.location == NSNotFound ? textView.selectedRange() : range
        let sourceRange = folds.sourceRange(for: displayRange)
        expandFolds()
        return sourceRange
    }

    @objc func prepareUndo(_ notification: Notification) {
        guard let manager = notification.object as? UndoManager,
              manager === textView.undoManager else { return }
        expandFolds()
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
        if foldedSource != nil {
            let range = folds.sourceRange(for: affectedCharRange)
            expandFolds()
            if let replacementString {
                textView.insertText(replacementString, replacementRange: range)
            }
            return false
        }
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
        scheduleFoldIndex()
        knownValidity = nil
        onTextChange?(nil)
    }

    func textViewDidChangeSelection(_: Notification) {
        guard !suppressChanges, isLineIndexReady,
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
                pendingEdit = nil
                return
            }

            let replacementRange = NSRange(
                location: replacedRange.location,
                length: replacementLength
            )
            guard replacementRange.location <= textStorage.length,
                  NSMaxRange(replacementRange) <= textStorage.length
            else {
                pendingEdit = nil
                shouldRebuildLineIndex = true
                return
            }

            edit = (
                range: replacedRange,
                replacement: textStorage.attributedSubstring(from: replacementRange).string
            )
        }
        pendingEdit = nil

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
