import AppKit
import SnapKit

/// 大文档使用原文坐标，TextKit 始终只接收至多三个分页
final class JSONViewportEditor: NSView {
    var onChange: ((Int?) -> Void)?
    var onCursor: ((Int, Int) -> Void)?
    var indentation = JSONIndentation.four
    var isEditable = true { didSet { textView.isEditable = isEditable } }
    var currentText = ""
    var selection = NSRange(location: 0, length: 0)
    var richContent: NSMutableAttributedString?

    let scrollView = NSScrollView()
    let surface = JSONViewportSurface()
    let textView = JSONTextView(frame: .zero)
    let lineIndex = JSONLineIndex()
    lazy var ruler = JSONLineNumberRulerView(textView: textView, lineIndex: lineIndex)
    var source: NSString = ""
    var blocks: [JSONViewportIndex.Block] = []
    var displayBlocks: [JSONViewportIndex.Block] = []
    var heights: [CGFloat] = []
    var offsets: [CGFloat] = [0]
    var folds = JSONFoldProjection()
    var page = NSRange(location: 0, length: 0)
    var pageText = ""
    var pageBlocks = 0..<0
    var pageWidth: CGFloat = 0
    var viewportSize = NSSize.zero
    var suppressChanges = false
    var isRendering = false
    var pendingAnchor: (location: Int, offset: CGFloat)?
    var pendingReplacement: NSRange?
    var indexTask: Task<Void, Never>?
    var highlightTask: Task<Void, Never>?
    var revision = 0
    let lineHeight: CGFloat = 17

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        indexTask?.cancel()
        highlightTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func layout() {
        super.layout()
        guard !textView.isHandlingInput, !textView.hasMarkedText() else { return }
        guard scrollView.contentSize.width > 0, !blocks.isEmpty else { return }
        let size = scrollView.contentSize
        let resized = bounds.size != viewportSize
        if resized || size.width != pageWidth {
            let anchor = scrollAnchor()
            viewportSize = bounds.size
            pageWidth = size.width
            rebuildHeights()
            pageBlocks = 0..<0
            if resized { scrollToTop() } else { restoreScrollAnchor(anchor) }
        }
        renderPage()
    }

    func setText(_ text: String, document: JSONFoldIndex.Document?, prepared: JSONPreparedText) {
        indexTask?.cancel()
        highlightTask?.cancel()
        revision += 1
        pendingAnchor = nil
        pendingReplacement = nil
        currentText = text
        if richContent != nil {
            richContent = NSMutableAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor
            ])
        }
        source = prepared.source
        blocks = prepared.index.blocks
        lineIndex.replace(with: document?.lineStarts ?? [0])
        folds.reset(nodes: document?.nodes ?? [])
        selection = NSRange(location: 0, length: 0)
        pageBlocks = 0..<0
        pageWidth = max(100, scrollView.contentSize.width)
        viewportSize = bounds.size
        rebuildProjection()
        scrollToTop()
        updateCursor()
    }

    func focus() { window?.makeFirstResponder(textView) }

    func scrollToTop() {
        selection = NSRange(location: 0, length: 0)
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        renderPage()
        suppressChanges = true
        restoreVisibleSelection()
        suppressChanges = false
        // 分页测量和光标恢复可能调整滚动位置，完成后再固定原点，保留文本内边距
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        ruler.refreshVisibleLines()
        updateCursor()
    }

    func cancelWork() {
        indexTask?.cancel()
        highlightTask?.cancel()
        undoManager?.removeAllActions()
    }

    func enableRichText() {
        richContent = NSMutableAttributedString()
        textView.isRichText = true
        textView.font = .systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.onCopyRich = { [weak self] in
            guard let self, let richContent else { return NSAttributedString() }
            return richContent.attributedSubstring(from: selection)
        }
        ruler.isHidden = true
        scrollView.snp.remakeConstraints { $0.edges.equalToSuperview() }
    }

    private func setup() {
        textView.isRichText = false
        textView.allowsUndo = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 10, height: 8)
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.layoutManager?.backgroundLayoutEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.delegate = self
        textView.onCopy = { [weak self] _ in self?.selectedText() ?? "" }
        textView.onSelectAll = { [weak self] in self?.selectAll() }
        textView.onPrepareEdit = { [weak self] range in self?.prepareEdit(range) ?? range }
        textView.onMove = { [weak self] command in self?.move(command) ?? false }
        textView.onInputChange = { [weak self] in self?.syncInput() }
        textView.onExpand = { [weak self] in
            if let self { _ = prepareEdit(textView.selectedRange()) }
        }
        ruler.sourceLocation = { [weak self] location in
            guard let self else { return location }
            return folds.sourceLocation(for: page.location + location)
        }
        ruler.foldAtLine = { [weak self] location in
            guard let self, let node = folds.node(atLineStart: location) else { return nil }
            return (node, folds.collapsed.contains(node))
        }
        ruler.onToggleFold = { [weak self] node in self?.toggleFold(node) }
        surface.addSubview(textView)
        scrollView.documentView = surface
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(didScroll), name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        addSubview(ruler)
        addSubview(scrollView)
        ruler.snp.makeConstraints { $0.top.leading.bottom.equalToSuperview() }
        scrollView.snp.makeConstraints {
            $0.top.trailing.bottom.equalToSuperview()
            $0.leading.equalTo(ruler.snp.trailing)
        }
    }
}
