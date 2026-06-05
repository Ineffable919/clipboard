//
//  SearchSuggestionViewController.swift
//  Clipboard
//
//  联想列表内容管理器：NSTableView
//

import AppKit
import SnapKit

final class SearchSuggestionViewController: NSViewController {
    // MARK: - Metrics

    private enum Metrics {
        static let rowHeight: CGFloat = 24
        static let maxVisibleRows: Int = 6
        static let verticalInset: CGFloat = 6
    }

    // MARK: - Properties

    private(set) var items: [SearchSuggestionItem] = []
    private var query: String = ""
    private var highlightedIndex: Int = -1

    var onSelectItem: ((SearchSuggestionItem) -> Void)?

    var preferredHeight: CGFloat {
        let count = min(items.count, Metrics.maxVisibleRows)
        return CGFloat(count) * Metrics.rowHeight + Metrics.verticalInset * 2
    }

    var isEmpty: Bool {
        items.isEmpty
    }

    // MARK: - Views

    private lazy var scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = false
        sv.drawsBackground = false
        sv.horizontalScrollElasticity = .none
        sv.verticalScrollElasticity = .none
        sv.contentInsets = NSEdgeInsets(
            top: Metrics.verticalInset,
            left: 0,
            bottom: Metrics.verticalInset,
            right: 0
        )
        sv.automaticallyAdjustsContentInsets = false
        return sv
    }()

    private lazy var tableView: NSTableView = {
        let tv = NSTableView()
        tv.headerView = nil
        tv.rowHeight = Metrics.rowHeight
        tv.intercellSpacing = .zero
        tv.backgroundColor = .clear
        tv.selectionHighlightStyle = .none
        tv.style = .plain

        let column = NSTableColumn(identifier: .init("suggestion"))
        column.isEditable = false
        column.resizingMask = .autoresizingMask
        tv.addTableColumn(column)

        tv.dataSource = self
        tv.delegate = self

        return tv
    }()

    private lazy var trackingArea = NSTrackingArea(
        rect: .zero,
        options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
        owner: self,
        userInfo: nil
    )

    // MARK: - Lifecycle

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        view = container

        scrollView.documentView = tableView
        container.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.addTrackingArea(trackingArea)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateTableColumnWidth()
    }

    // MARK: - Public API

    func reloadData(_ newItems: [SearchSuggestionItem], query: String) {
        items = newItems
        self.query = query
        highlightedIndex = newItems.isEmpty ? -1 : 0
        tableView.reloadData()
        syncLayoutToVisibleBounds()
        if !newItems.isEmpty {
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: -scrollView.contentInsets.top))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
        updateHighlight()
    }

    func syncLayoutToVisibleBounds() {
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        scrollView.needsLayout = true
        scrollView.layoutSubtreeIfNeeded()
        updateTableColumnWidth()
        tableView.tile()
    }

    // MARK: - Keyboard Navigation

    func selectNext() -> Bool {
        guard !items.isEmpty else { return false }
        if highlightedIndex >= items.count - 1 {
            NSSound.beep()
            return true
        }
        highlightedIndex += 1
        updateHighlight()
        tableView.animator().scrollRowToVisible(highlightedIndex)
        return true
    }

    func selectPrevious() -> Bool {
        guard !items.isEmpty else { return false }
        if highlightedIndex <= 0 {
            NSSound.beep()
            return true
        }
        highlightedIndex -= 1
        updateHighlight()
        tableView.animator().scrollRowToVisible(highlightedIndex)
        return true
    }

    func applySelection() -> Bool {
        guard highlightedIndex >= 0, highlightedIndex < items.count else { return false }
        onSelectItem?(items[highlightedIndex])
        return true
    }

    // MARK: - Mouse Tracking

    override func mouseMoved(with event: NSEvent) {
        let point = tableView.convert(event.locationInWindow, from: nil)
        let row = tableView.row(at: point)
        guard row >= 0, row != highlightedIndex else { return }
        highlightedIndex = row
        updateHighlight()
    }

    // MARK: - Click Handling

    func handleClick(at point: NSPoint) {
        let localPoint = tableView.convert(point, from: nil)
        let row = tableView.row(at: localPoint)
        guard row >= 0, row < items.count else { return }
        onSelectItem?(items[row])
    }

    // MARK: - Private

    private func updateHighlight() {
        for row in 0 ..< tableView.numberOfRows {
            let isSelected = row == highlightedIndex

            if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false)
                as? SearchSuggestionRowView
            {
                rowView.setItemHighlighted(isSelected)
            }

            if let cellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false)
                as? SearchSuggestionCellView
            {
                cellView.setHighlighted(isSelected)
            }
        }
    }

    private func updateTableColumnWidth() {
        guard let column = tableView.tableColumns.first else { return }
        let width = scrollView.contentView.bounds.width
        guard width > 0 else { return }
        tableView.frame.size.width = width
        column.width = width
    }
}

// MARK: - NSTableViewDataSource

extension SearchSuggestionViewController: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        items.count
    }
}

// MARK: - NSTableViewDelegate

extension SearchSuggestionViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("SuggestionCell")
        let cellView = (tableView.makeView(withIdentifier: id, owner: nil) as? SearchSuggestionCellView)
            ?? SearchSuggestionCellView()
        cellView.identifier = id

        if row < items.count {
            cellView.configure(item: items[row], query: query)
            cellView.setHighlighted(row == highlightedIndex)
        }
        return cellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let id = NSUserInterfaceItemIdentifier("SuggestionRowView")
        let rowView = (tableView.makeView(withIdentifier: id, owner: nil) as? SearchSuggestionRowView)
            ?? SearchSuggestionRowView()
        rowView.identifier = id
        rowView.setItemHighlighted(row == highlightedIndex)
        return rowView
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        Metrics.rowHeight
    }

    func tableView(_: NSTableView, shouldSelectRow _: Int) -> Bool {
        false
    }
}
