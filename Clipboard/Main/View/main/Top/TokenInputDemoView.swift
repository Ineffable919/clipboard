//
//  TokenInputDemoView.swift
//  Clipboard
//
//  Created by Codex on 2026/4/1.
//

import AppKit
import SwiftUI

// MARK: - SwiftUI host

struct TokenInputDemoView: View {
    var body: some View {
        DemoTokenInputRepresentable()
            .frame(height: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        .white, Color(red: 0.98, green: 0.98, blue: 0.985),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

// MARK: - Suggestion item (unified model for type / app / date suggestions)

private struct SuggestionItem: Hashable {
    enum Kind: Hashable {
        case type(String) // PasteModelType.rawValue
        case app(String) // app name
        case date(String) // DateFilterOption.rawValue
    }

    let kind: Kind
    let icon: NSImage
    let label: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.kind == rhs.kind
    }
}

// MARK: - Style

private enum TagFonts {
    nonisolated(unsafe) static let tag = NSFont.systemFont(
        ofSize: 12,
        weight: .regular
    )
    nonisolated(unsafe) static let input = NSFont.systemFont(
        ofSize: 13,
        weight: .regular
    )
}

private enum TagColors {
    static let foreground = NSColor.labelColor
    static let fill = NSColor.tertiaryLabelColor.withAlphaComponent(0.12)
}

private enum TagMetrics {
    static let iconSize: CGFloat = 14
    static let hPad: CGFloat = 8
    static let textSpacing: CGFloat = 4
    static let vPad: CGFloat = 3
    static let height: CGFloat = 21 // ceil(systemFont(12).ascender - descender) + vPad * 2
    static let cornerRadius: CGFloat = 10.5 // height / 2
}

private enum SuggestionStyle {
    static let rowHeight: CGFloat = 26
    static let rowCornerRadius: CGFloat = 12
    static let sideInset: CGFloat = 6
    static let iconBoxSize: CGFloat = 16
    static let titleFont = NSFont.systemFont(ofSize: 12, weight: .regular)
    static let selectedFill = NSColor.controlAccentColor
}

// MARK: - NSTextAttachment for InputTag rendering

private final class InputTagAttachment: NSTextAttachment {
    init(icon: NSImage, label: String) {
        super.init(data: nil, ofType: nil)
        attachmentCell = InputTagAttachmentCell(icon: icon, label: label)
    }

    override nonisolated init(data: Data?, ofType uti: String?) {
        super.init(data: data, ofType: uti)
    }

    @available(*, unavailable)
    required nonisolated init?(coder _: NSCoder) {
        nil
    }

    override nonisolated func attachmentBounds(
        for _: NSTextContainer?,
        proposedLineFragment lineFrag: NSRect,
        glyphPosition _: CGPoint,
        characterIndex _: Int
    ) -> NSRect {
        guard let cell = attachmentCell else { return .zero }
        let size = cell.cellSize()
        let y = lineFrag.origin.y + floor((lineFrag.height - size.height) / 2)
        return NSRect(x: 0, y: y, width: size.width, height: size.height)
    }
}

private final class InputTagAttachmentCell: NSTextAttachmentCell {
    let tagIcon: NSImage
    let tagLabel: String

    init(icon: NSImage, label: String) {
        tagIcon = icon
        tagLabel = label
        super.init()
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError()
    }

    private nonisolated func tagSize() -> NSSize {
        let hPad: CGFloat = 8
        let iconSize: CGFloat = 14
        let textSpacing: CGFloat = 4
        let height: CGFloat = 21
        let attrs: [NSAttributedString.Key: Any] = [.font: TagFonts.tag]
        let titleW = (tagLabel as NSString).size(withAttributes: attrs).width
        let w = hPad + iconSize + textSpacing + titleW + hPad
        return NSSize(width: ceil(w), height: height)
    }

    override nonisolated func cellSize() -> NSSize {
        tagSize()
    }

    override func draw(withFrame cellFrame: NSRect, in _: NSView?) {
        // Pill background
        TagColors.fill.setFill()
        NSBezierPath(
            roundedRect: cellFrame,
            xRadius: TagMetrics.cornerRadius,
            yRadius: TagMetrics.cornerRadius
        ).fill()

        // Icon
        let iconY =
            cellFrame.origin.y + floor((cellFrame.height - TagMetrics.iconSize) / 2)
        tagIcon.size = NSSize(
            width: TagMetrics.iconSize,
            height: TagMetrics.iconSize
        )
        tagIcon.draw(
            in: NSRect(
                x: cellFrame.origin.x + TagMetrics.hPad,
                y: iconY,
                width: TagMetrics.iconSize,
                height: TagMetrics.iconSize
            ),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )

        // Label
        let attrs: [NSAttributedString.Key: Any] = [
            .font: TagFonts.tag, .foregroundColor: TagColors.foreground,
        ]
        let titleSize = (tagLabel as NSString).size(withAttributes: attrs)
        let titleX =
            cellFrame.origin.x + TagMetrics.hPad + TagMetrics.iconSize
                + TagMetrics.textSpacing
        let titleY = cellFrame.origin.y + floor((cellFrame.height - titleSize.height) / 2)
        (tagLabel as NSString).draw(
            at: NSPoint(x: titleX, y: titleY),
            withAttributes: attrs
        )
    }

    override func draw(
        withFrame cellFrame: NSRect,
        in controlView: NSView?,
        characterIndex _: Int,
        layoutManager _: NSLayoutManager
    ) {
        draw(withFrame: cellFrame, in: controlView)
    }
}

private func makeTagAttachment(icon: NSImage, label: String)
    -> NSAttributedString
{
    let attachment = InputTagAttachment(icon: icon, label: label)
    return NSAttributedString(attachment: attachment)
}

// MARK: - NSViewRepresentable

private struct DemoTokenInputRepresentable: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> DemoTokenInputRootView {
        let rootView = DemoTokenInputRootView()
        let textView = DemoTokenTextView(frame: .zero)
        let suggestionsView = DemoSuggestionListView()

        textView.coordinator = context.coordinator
        suggestionsView.onSelect = { [weak c = context.coordinator] item in
            c?.applySuggestion(item)
        }

        rootView.embed(textView: textView, suggestionsView: suggestionsView)
        rootView.setCoordinator(context.coordinator)

        context.coordinator.textView = textView
        context.coordinator.rootView = rootView
        context.coordinator.suggestionsView = suggestionsView
        textView.loadDemoContent()
        context.coordinator.refreshLayout()

        // Load suggestion data (simulating FilterPopoverView data sources)
        Task { @MainActor in
            await context.coordinator.loadSuggestionSources()
            context.coordinator.updateSuggestions()
        }

        return rootView
    }

    func updateNSView(_: DemoTokenInputRootView, context _: Context) {}
}

// MARK: - Coordinator

extension DemoTokenInputRepresentable {
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: DemoTokenTextView?
        weak var rootView: DemoTokenInputRootView?
        weak var suggestionsView: DemoSuggestionListView?
        let filterPopover = NSPopover()

        /// All available suggestion items (types + apps + dates)
        var allSuggestions: [SuggestionItem] = []
        var filteredItems: [SuggestionItem] = []
        var selectedIndex = 0

        // MARK: Load suggestion sources (mirrors FilterPopoverView data)

        func loadSuggestionSources() async {
            var items: [SuggestionItem] = []

            // 1. Type suggestions
            let tagTypes = await PasteMetadataCache.shared.getAllTagTypes()
            for type in tagTypes {
                let iconAndLabel = type.iconAndLabel
                guard !iconAndLabel.icon.isEmpty else { continue }
                let img =
                    NSImage(
                        systemSymbolName: iconAndLabel.icon,
                        accessibilityDescription: iconAndLabel.label
                    )
                    ?? NSImage(
                        systemSymbolName: "questionmark",
                        accessibilityDescription: nil
                    )!
                items.append(
                    SuggestionItem(
                        kind: .type(type.rawValue),
                        icon: img,
                        label: iconAndLabel.label
                    )
                )
            }

            // 2. App suggestions
            let rawAppInfo = await PasteMetadataCache.shared.getAllAppInfo()
            for info in rawAppInfo {
                let icon = await AppIconCache.shared.loadIcon(
                    forPath: info.path
                )
                items.append(
                    SuggestionItem(
                        kind: .app(info.name),
                        icon: icon,
                        label: info.name
                    )
                )
            }

            // 3. Date suggestions
            for option in TopBarViewModel.DateFilterOption.allCases {
                let img = NSImage(
                    systemSymbolName: "calendar",
                    accessibilityDescription: option.displayName
                )!
                items.append(
                    SuggestionItem(
                        kind: .date(option.rawValue),
                        icon: img,
                        label: option.displayName
                    )
                )
            }

            allSuggestions = items
        }

        // MARK: Layout & suggestions

        func refreshLayout() {
            guard let textView else { return }
            textView.updateWidthToFitContent()
            textView.scrollRangeToVisible(textView.selectedRange())
        }

        func updateSuggestions() {
            guard let textView, let suggestionsView, let rootView else {
                return
            }
            let keyword = textView.currentWord()
            guard !allSuggestions.isEmpty else {
                filteredItems = []
                suggestionsView.items = []
                rootView.setSuggestionsHidden(true)
                return
            }

            if keyword.isEmpty {
                filteredItems = []
                suggestionsView.items = []
                rootView.setSuggestionsHidden(true)
                return
            } else {
                filteredItems = allSuggestions.filter {
                    $0.label.localizedStandardContains(keyword)
                }
            }

            guard !filteredItems.isEmpty else {
                suggestionsView.items = []
                rootView.setSuggestionsHidden(true)
                return
            }
            selectedIndex = min(selectedIndex, filteredItems.count - 1)
            suggestionsView.items = filteredItems
            suggestionsView.selectedIndex = selectedIndex
            suggestionsView.reload()
            rootView.setSuggestionsHidden(false)
        }

        func hideSuggestions() {
            suggestionsView?.items = []
            rootView?.setSuggestionsHidden(true)
        }

        func moveSelectionDown() {
            guard !filteredItems.isEmpty else { return }
            selectedIndex = min(selectedIndex + 1, filteredItems.count - 1)
            suggestionsView?.selectedIndex = selectedIndex
            suggestionsView?.reload()
        }

        func moveSelectionUp() {
            guard !filteredItems.isEmpty else { return }
            selectedIndex = max(selectedIndex - 1, 0)
            suggestionsView?.selectedIndex = selectedIndex
            suggestionsView?.reload()
        }

        func confirmSuggestion() -> Bool {
            guard filteredItems.indices.contains(selectedIndex) else {
                return false
            }
            applySuggestion(filteredItems[selectedIndex])
            return true
        }

        func applySuggestion(_ item: SuggestionItem) {
            textView?.replaceCurrentWord(with: item)
            selectedIndex = 0
            hideSuggestions()
        }

        func showFilterMenu(from button: NSButton) {
            let vc = DemoFilterPopoverViewController()
            filterPopover.contentViewController = vc
            filterPopover.behavior = .transient
            filterPopover.animates = false
            if filterPopover.isShown {
                filterPopover.performClose(nil)
            } else {
                filterPopover.show(
                    relativeTo: button.bounds,
                    of: button,
                    preferredEdge: .maxY
                )
            }
        }

        // MARK: NSTextViewDelegate

        func textDidChange(_: Notification) {
            refreshLayout()
            updateSuggestions()
        }

        func textViewDidChangeSelection(_: Notification) {
            refreshLayout()
        }
    }
}

// MARK: - Token text view

private final class DemoTokenTextView: NSTextView {
    weak var coordinator: DemoTokenInputRepresentable.Coordinator?

    override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, textContainer: nil)
    }

    override init(frame frameRect: NSRect, textContainer _: NSTextContainer?) {
        let storage = NSTextStorage()
        let lm = NSLayoutManager()
        let h: CGFloat = 24
        let tc = NSTextContainer(
            size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: h)
        )
        tc.widthTracksTextView = false
        tc.heightTracksTextView = false
        lm.addTextContainer(tc)
        storage.addLayoutManager(lm)
        super.init(frame: frameRect, textContainer: tc)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private func setup() {
        let h: CGFloat = 24
        isEditable = true
        isSelectable = true
        isRichText = true
        drawsBackground = false
        allowsUndo = true
        isHorizontallyResizable = true
        isVerticallyResizable = false
        textContainerInset = NSSize(width: 8, height: 0)
        insertionPointColor = .labelColor
        font = TagFonts.input
        textContainer?.lineFragmentPadding = 0
        textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: h
        )
        textContainer?.widthTracksTextView = false
        minSize = NSSize(width: 200, height: h)
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: h)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        delegate = coordinator
    }

    func loadDemoContent() {
        guard let ts = textStorage else { return }
        let content = NSMutableAttributedString()

        let imgIcon =
            NSImage(
                systemSymbolName: "photo",
                accessibilityDescription: "Image"
            ) ?? NSImage()
        content.append(
            makeTagAttachment(icon: imgIcon, label: String(localized: .image))
        )
        content.append(
            NSAttributedString(string: " ", attributes: [.font: TagFonts.input])
        )

        content.append(
            NSAttributedString(string: " ", attributes: [.font: TagFonts.input])
        )

        ts.setAttributedString(content)
        setSelectedRange(NSRange(location: ts.length, length: 0))
        updateWidthToFitContent()
    }

    func currentWord() -> String {
        let cursor = selectedRange().location
        guard cursor <= string.utf16.count else { return "" }
        let prefix = String(string.prefix(cursor))
        let seps = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(CharacterSet(charactersIn: "\u{FFFC}"))
        let parts = prefix.split { ch in
            ch.unicodeScalars.allSatisfy(seps.contains(_:))
        }
        return parts.last.map(String.init) ?? ""
    }

    func replaceCurrentWord(with item: SuggestionItem) {
        guard let ts = textStorage else { return }
        let word = currentWord()
        let cursor = selectedRange().location
        let range = NSRange(
            location: max(0, cursor - word.utf16.count),
            length: word.utf16.count
        )
        let replacement = NSMutableAttributedString()
        replacement.append(
            makeTagAttachment(icon: item.icon, label: item.label)
        )
        replacement.append(
            NSAttributedString(string: " ", attributes: [.font: TagFonts.input])
        )
        ts.replaceCharacters(in: range, with: replacement)
        setSelectedRange(NSRange(location: range.location + 2, length: 0))
        coordinator?.refreshLayout()
    }

    func updateWidthToFitContent() {
        guard let lm = layoutManager, let tc = textContainer else { return }
        let h: CGFloat = 24
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc)
        frame = NSRect(
            x: 0,
            y: 0,
            width: max(220, ceil(used.width + 24)),
            height: h
        )
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125:
            coordinator?.moveSelectionDown()
            return
        case 126:
            coordinator?.moveSelectionUp()
            return
        case 36: if coordinator?.confirmSuggestion() == true { return }
        case 53: coordinator?.hideSuggestions()
        default: break
        }
        super.keyDown(with: event)
    }
}

// MARK: - Root view

private final class DemoTokenInputRootView: NSView {
    private let inputContainer = NSView()
    private let scrollView = DemoHorizontalScrollView()
    private let filterButton = NSButton()
    private let searchIcon = NSImageView()
    private var suggestionsHeightConstraint: NSLayoutConstraint?
    private var suggestionsWidthConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    @available(*, unavailable) required init?(coder _: NSCoder) {
        fatalError()
    }

    func embed(
        textView: DemoTokenTextView,
        suggestionsView: DemoSuggestionListView
    ) {
        scrollView.documentView = textView
        suggestionsView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(suggestionsView)
        suggestionsHeightConstraint = suggestionsView.heightAnchor.constraint(
            equalToConstant: 0
        )
        suggestionsWidthConstraint = suggestionsView.widthAnchor.constraint(
            equalToConstant: 200
        )
        NSLayoutConstraint.activate([
            suggestionsView.leadingAnchor.constraint(
                equalTo: inputContainer.leadingAnchor
            ),
            suggestionsView.topAnchor.constraint(
                equalTo: inputContainer.bottomAnchor
            ),
            suggestionsHeightConstraint!,
            suggestionsWidthConstraint!,
        ])
        suggestionsView.isHidden = true
    }

    func setCoordinator(_ coordinator: DemoTokenInputRepresentable.Coordinator) {
        filterButton.target = coordinator
        filterButton.action = #selector(handleFilterButton(_:))
    }

    func setSuggestionsHidden(_ hidden: Bool) {
        guard
            let sv = subviews.compactMap({ $0 as? DemoSuggestionListView })
            .first
        else { return }
        sv.isHidden = hidden
        suggestionsHeightConstraint?.constant = hidden ? 0 : sv.fittingHeight
        if !hidden {
            suggestionsWidthConstraint?.constant = sv.fittingWidth
        }
    }

    private func configure() {
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor =
            NSColor.black.withAlphaComponent(0.1).cgColor
        inputContainer.layer?.cornerRadius = 16
        inputContainer.layer?.borderWidth = 1
        inputContainer.layer?.borderColor =
            NSColor.black.withAlphaComponent(0.1).cgColor

        addSubview(inputContainer)

        // Magnifying glass icon — mirrors the leading icon in searchField
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.image = NSImage(
            systemSymbolName: "magnifyingglass",
            accessibilityDescription: "Search"
        )
        searchIcon.contentTintColor = .secondaryLabelColor
        searchIcon.imageScaling = .scaleProportionallyUpOrDown

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .allowed

        filterButton.translatesAutoresizingMaskIntoConstraints = false
        filterButton.title = ""
        filterButton.image = NSImage(
            systemSymbolName: "line.3.horizontal.decrease",
            accessibilityDescription: "Filter"
        )
        filterButton.image?.size = NSSize(width: 12, height: 12)
        filterButton.isBordered = false
        filterButton.bezelStyle = .regularSquare
        filterButton.contentTintColor = .secondaryLabelColor
        filterButton.wantsLayer = true
        filterButton.layer?.cornerRadius = 8

        inputContainer.addSubview(searchIcon)
        inputContainer.addSubview(scrollView)
        inputContainer.addSubview(filterButton)

        NSLayoutConstraint.activate([
            inputContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            inputContainer.topAnchor.constraint(equalTo: topAnchor),
            inputContainer.heightAnchor.constraint(equalToConstant: 36),
            // Search icon — left side, fixed width, centered vertically
            searchIcon.leadingAnchor.constraint(
                equalTo: inputContainer.leadingAnchor,
                constant: 8
            ),
            searchIcon.centerYAnchor.constraint(
                equalTo: inputContainer.centerYAnchor
            ),
            searchIcon.widthAnchor.constraint(equalToConstant: 16),
            searchIcon.heightAnchor.constraint(equalToConstant: 16),
            // Filter button — right side
            filterButton.trailingAnchor.constraint(
                equalTo: inputContainer.trailingAnchor,
                constant: -8
            ),
            filterButton.centerYAnchor.constraint(
                equalTo: inputContainer.centerYAnchor
            ),
            filterButton.widthAnchor.constraint(equalToConstant: 24),
            filterButton.heightAnchor.constraint(equalToConstant: 24),
            // Scroll view fills space between icon and filter button
            scrollView.leadingAnchor.constraint(
                equalTo: searchIcon.trailingAnchor,
                constant: 6
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: filterButton.leadingAnchor,
                constant: -6
            ),
            scrollView.topAnchor.constraint(
                equalTo: inputContainer.topAnchor,
                constant: 6
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: inputContainer.bottomAnchor,
                constant: -6
            ),
        ])
    }

    @objc private func handleFilterButton(_ sender: NSButton) {
        guard let t = sender.target as? DemoTokenInputRepresentable.Coordinator
        else { return }
        t.showFilterMenu(from: sender)
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private final class DemoHorizontalScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        let h = abs(event.scrollingDeltaX)
        let v = abs(event.scrollingDeltaY)
        guard v > h else {
            super.scrollWheel(with: event)
            return
        }
        let maxX = max(
            0,
            (documentView?.frame.width ?? 0) - contentView.bounds.width
        )
        let proposed = contentView.bounds.origin.x + event.scrollingDeltaY
        contentView.setBoundsOrigin(
            NSPoint(x: min(max(0, proposed), maxX), y: 0)
        )
        reflectScrolledClipView(contentView)
    }
}

// MARK: - Suggestion list view

private final class DemoSuggestionListView: NSView {
    var items: [SuggestionItem] = []
    var selectedIndex = 0
    var onSelect: ((SuggestionItem) -> Void)?
    private let scrollView = NSScrollView()
    private let docView = FlippedView()
    private let stackView = NSStackView()

    var fittingHeight: CGFloat {
        let rows = min(max(items.count, 1), 6)
        return CGFloat(rows) * (SuggestionStyle.rowHeight + 4) + 16
    }

    /// Width that fits the widest suggestion label.
    var fittingWidth: CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: SuggestionStyle.titleFont,
        ]
        let maxLabelW =
            items.map {
                ($0.label as NSString).size(withAttributes: attrs).width
            }.max() ?? 80
        // row: leading(8) + icon(24) + spacing(8) + label + trailing(12) = 52
        // list side insets: sideInset * 2 = 16
        return ceil(maxLabelW + 52 + 16)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    @available(*, unavailable) required init?(coder _: NSCoder) {
        fatalError()
    }

    func reload() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, item) in items.enumerated() {
            let row = DemoSuggestionRow()
            row.identifier = NSUserInterfaceItemIdentifier("\(i)")
            row.configure(item: item, isSelected: i == selectedIndex)
            row.target = self
            row.action = #selector(handleSelect(_:))
            stackView.addArrangedSubview(row)
        }
        needsLayout = true
        // 布局完成后滚动到选中项
        DispatchQueue.main.async { [weak self] in
            self?.scrollToSelected()
        }
    }

    private func scrollToSelected() {
        guard selectedIndex >= 0,
              selectedIndex < stackView.arrangedSubviews.count
        else { return }
        let rowH = SuggestionStyle.rowHeight + stackView.spacing
        let rowY = CGFloat(selectedIndex) * rowH
        let rowRect = NSRect(x: 0, y: rowY, width: 1, height: SuggestionStyle.rowHeight)
        let visible = scrollView.contentView.bounds
        // 已在可见区域内则不滚动
        guard !visible.contains(rowRect), !visible.intersects(rowRect) else { return }
        let targetY: CGFloat = if rowY < visible.minY {
            rowY
        } else {
            rowY + SuggestionStyle.rowHeight - visible.height
        }
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    override func layout() {
        super.layout()
        let inset = SuggestionStyle.sideInset
        scrollView.frame = NSRect(
            x: inset,
            y: 8,
            width: max(0, bounds.width - inset * 2),
            height: max(0, bounds.height - 16)
        )
        // docView / stackView 使用 frame 布局，高度由行数决定，宽度跟随 scrollView
        let w = scrollView.contentView.bounds.width
        guard w > 0 else { return }
        let rowH = SuggestionStyle.rowHeight + stackView.spacing
        let contentH = max(
            CGFloat(stackView.arrangedSubviews.count) * rowH,
            scrollView.contentView.bounds.height
        )
        stackView.frame = NSRect(x: 0, y: 0, width: w, height: contentH)
        docView.frame = NSRect(x: 0, y: 0, width: w, height: contentH)
        // 让每一行宽度撑满容器
        for row in stackView.arrangedSubviews.compactMap({
            $0 as? DemoSuggestionRow
        }) {
            row.setPreferredWidth(w)
        }
    }

    private func configure() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.cornerRadius = Const.radius
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.black.withAlphaComponent(0.06).cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.10).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = 20
        layer?.shadowOffset = CGSize(width: 0, height: -6)

        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .allowed

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4

        docView.addSubview(stackView)
        scrollView.documentView = docView
        addSubview(scrollView)
    }

    @objc private func handleSelect(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let i = Int(raw),
              items.indices.contains(i)
        else { return }
        onSelect?(items[i])
    }
}

// MARK: - Suggestion row

private final class DemoSuggestionRow: NSButton {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")

    private var rowWidthConstraint: NSLayoutConstraint?

    override init(frame: NSRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    @available(*, unavailable) required init?(coder _: NSCoder) {
        fatalError()
    }

    func setPreferredWidth(_ w: CGFloat) {
        if let c = rowWidthConstraint {
            c.constant = w
        } else {
            let c = widthAnchor.constraint(equalToConstant: w)
            c.isActive = true
            rowWidthConstraint = c
        }
    }

    func configure(item: SuggestionItem, isSelected: Bool) {
        title = ""
        iconView.image = item.icon
        titleLabel.stringValue = item.label
        wantsLayer = true
        layer?.cornerRadius = SuggestionStyle.rowCornerRadius

        if isSelected {
            layer?.backgroundColor = SuggestionStyle.selectedFill.cgColor
            titleLabel.textColor = .white
            iconView.contentTintColor = .white
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            titleLabel.textColor = .labelColor
            iconView.contentTintColor = .secondaryLabelColor
        }
    }

    private func configureSubviews() {
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        bezelStyle = .roundRect
        focusRingType = .none
        setButtonType(.momentaryPushIn)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = SuggestionStyle.titleFont
        titleLabel.lineBreakMode = .byTruncatingTail

        addSubview(iconView)
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: SuggestionStyle.rowHeight),
            iconView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 8
            ),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(
                equalToConstant: SuggestionStyle.iconBoxSize
            ),
            iconView.heightAnchor.constraint(
                equalToConstant: SuggestionStyle.iconBoxSize
            ),
            titleLabel.leadingAnchor.constraint(
                equalTo: iconView.trailingAnchor,
                constant: 8
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -12
            ),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}

// MARK: - Filter popover (placeholder)

private final class DemoFilterPopoverViewController: NSViewController {
    override func loadView() {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 8
        s.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        for t in ["Type", "App", "Date"] {
            let l = NSTextField(labelWithString: t)
            l.font = .systemFont(ofSize: 12, weight: .medium)
            s.addArrangedSubview(l)
        }
        view = s
        preferredContentSize = NSSize(width: 140, height: 100)
    }
}

#Preview { TokenInputDemoView() }
