//
//  JSONEditorView.swift
//  Clipboard
//

import AppKit
import SnapKit

final class JSONEditorView: NSView {
    static let lightString = NSColor(hex: "#008000")
    static let lightNumber = NSColor(hex: "#3322FF")
    static let lightLiteral = NSColor(hex: "#B333B3")

    static let darkString = NSColor(hex: "#7ECF87")
    static let darkNumber = NSColor(hex: "#8FA8FF")
    static let darkLiteral = NSColor(hex: "#D99BE5")

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

    var preparedContent: JSONPreparedText? {
        guard let viewport else { return nil }
        return JSONPreparedText(source: viewport.source, index: .init(blocks: viewport.blocks))
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

    let scrollView: NSScrollView
    var textView: JSONTextView
    let lineIndex = JSONLineIndex()
    lazy var lineRuler = JSONLineNumberRulerView(
        textView: textView,
        lineIndex: lineIndex
    )

    // MARK: - Tasks

    var lineTask: Task<Void, Never>?
    var lineNumberTask: Task<Void, Never>?
    var highlightTask: Task<Void, Never>?
    var foldTask: Task<Void, Never>?
    var restoreTask: Task<Void, Never>?
    var scrollTask: Task<Void, Never>?
    var foldRequestID = 0
    var folds = JSONFoldProjection()
    var foldedSource: String?
    var preparedText: JSONPreparedText?
    var viewport: JSONViewportEditor?
    var highlightRequestID = 0
    var highlightWorkerID = 0
    var generation = 0
    var lineNumberViewportSize = NSSize.zero
    var editorSize = NSSize.zero
    var highlightedRange = NSRange(location: 0, length: 0)
    var highlightedGeneration = -1
    var reportedSelection = NSRange(location: NSNotFound, length: 0)
    var pendingEdit: (range: NSRange, replacement: String)?
    var lineIndexRevision = 0
    var reportedLineIndexRevision = -1
    var shouldRebuildLineIndex = false
    var suppressChanges = false
    var isLineIndexReady = false
    var isClosed = false

    var baseTextAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor
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

    func configureTextView() {
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

    func setup() {
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

}
