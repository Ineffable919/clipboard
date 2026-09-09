//
//  FloatingHistoryView.swift
//  Clipboard
//
//  浮动窗口历史记录列表：NSCollectionView + DiffableDataSource
//

import AppKit
import Combine
import SnapKit

// MARK: - FloatingHistoryView

final class FloatingHistoryView: NSView {
    // MARK: - Subviews

    let scrollView = NSScrollView()
    let collectionView = ClipCollectionView()
    let collectionLayout = NSCollectionViewFlowLayout()
    let emptyStateView = EmptyStateView(style: .floating)
    private(set) var displayMode: FloatingDisplayMode = .standard
    var scrollInsets: NSEdgeInsets {
        NSEdgeInsets(
            top: displayMode.headerHeight + displayMode.cardSpacing + Const.selectionBorderWidth,
            left: displayMode.cardInset,
            bottom: displayMode.footerHeight + displayMode.cardSpacing,
            right: displayMode.cardInset
        )
    }

    // MARK: - Data Source

    var dataSource:
        NSCollectionViewDiffableDataSource<Int, PasteboardModel>!

    // MARK: - State

    let dataStore = PasteDataStore.main
    let env = AppEnvironment.shared
    weak var topVM: TopBarViewModel?
    private let presenter = ClipListPresenter()

    var dataList: [PasteboardModel] = []
    var selectedIndex: Int = 0
    var isQuickPastePressed: Bool = false
    var isPlainTextModifierPressed: Bool = false
    private var dragSourceApp: NSRunningApplication?

    var onActivateSearch: ((String?) -> Void)?
    var onTogglePreview: ((Int) -> Void)?
    var onCreateChip: ((PasteboardModel) -> Void)?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func layout() {
        super.layout()
        let width = scrollView.contentSize.width - scrollInsets.left - scrollInsets.right
        let size = NSSize(width: width, height: displayMode.cardHeight)
        guard width > 0, collectionLayout.itemSize != size else { return }
        collectionLayout.itemSize = size
        collectionLayout.invalidateLayout()
    }

    // MARK: - Public API

    func setDisplayMode(_ mode: FloatingDisplayMode) {
        guard displayMode != mode else { return }
        displayMode = mode
        collectionLayout.minimumLineSpacing = mode.cardSpacing
        collectionLayout.sectionInset = scrollInsets
        scrollView.scrollerInsets = NSEdgeInsets(
            top: scrollInsets.top, left: 0, bottom: scrollInsets.bottom, right: 0
        )
        presenter.loadMoreThreshold = (mode.cardHeight + mode.cardSpacing) * 5
        needsLayout = true
        let selectedPaths = collectionView.selectionIndexPaths
        var snapshot = dataSource.snapshot()
        snapshot.reloadItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            guard let self else { return }
            collectionView.selectionIndexPaths = selectedPaths
            updateSelectedItemBorder()
            updateQuickPasteDisplay()
        }
    }

    func setPreviewHooks(
        isShown: @escaping () -> Bool,
        close: @escaping () -> Void,
        reopen: @escaping () -> Void
    ) {
        presenter.previewIsShown = isShown
        presenter.closePreview = close
        presenter.reopenPreview = reopen
    }

    func configure(topVM: TopBarViewModel) {
        self.topVM = topVM
        dataList = dataStore.dataList.value
        env.focusRegion = .collection
        applySnapshot()
        resetToFirst()
        configurePresenter()
        Task { @MainActor [weak self] in
            guard let self else { return }
            window?.makeFirstResponder(collectionView)
        }
    }

    private func configurePresenter() {
        presenter.applyFull = { [weak self] items, animating, completion in
            guard let self else { return }
            dataList = items
            applySnapshot(animating: animating)
            completion?()
        }
        setupReorder()
        presenter.appendItems = { [weak self] newItems in
            guard let self else { return }
            var snapshot = dataSource.snapshot()
            let existing = Set(snapshot.itemIdentifiers.map(\.uniqueId))
            let appended = newItems
                .filter { !existing.contains($0.uniqueId) }
            guard !appended.isEmpty else { return }
            dataList.append(contentsOf: appended)
            snapshot.appendItems(appended, toSection: 0)
            dataSource.apply(snapshot, animatingDifferences: false)
        }
        presenter.currentSnapshotItems = { [weak self] in self?.dataList ?? [] }
        presenter.resetSelection = { [weak self] in self?.resetToFirst() }
        presenter.restoreSelection = { [weak self] in self?.restoreSelection() }
        presenter.adjustAfterDelete = { [weak self] in self?.adjustSelectionAfterDelete() }
        presenter.updateEmptyState = { [weak self] isEmpty in
            self?.emptyStateView.isHidden = !isEmpty
        }
        presenter.reconfigureItems = { [weak self] items in
            guard let self else { return }
            let identifiers = dataSource.snapshot().itemIdentifiers
            let indexMap = Dictionary(uniqueKeysWithValues: identifiers.enumerated().map { ($1.uniqueId, $0) })
            let focused = env.focusRegion == .collection
            for item in items {
                guard let idx = indexMap[item.uniqueId] else { continue }
                (collectionView.item(at: IndexPath(item: idx, section: 0)) as? FloatingCollectionItem)?
                    .configure(
                        with: item,
                        keyword: topVM?.query ?? "",
                        isFocused: focused,
                        quickPasteIndex: quickPasteDisplayIndex(for: idx),
                        displayMode: displayMode
                    )
            }
        }

        presenter.isVerticalScroll = true
        presenter.loadMoreThreshold = (FloatConst.cardHeight + FloatConst.cardSpacing) * 5

        presenter.startObserving(scrollView: scrollView)
    }

    private func setupReorder() {
        presenter.applyReorder = { [weak self] items in
            guard let self else { return }
            let selectedID = dataList.indices.contains(selectedIndex) ? dataList[selectedIndex].id : nil
            dataList = items
            selectedIndex = items.firstIndex { $0.id == selectedID } ?? 0
            var snapshot = NSDiffableDataSourceSnapshot<Int, PasteboardModel>()
            snapshot.appendSections([0])
            snapshot.appendItems(items)
            // 浮动卡片的操作闭包包含行号，重排后需重新提供 item。
            let existing = Set(dataSource.snapshot().itemIdentifiers)
            snapshot.reloadItems(items.filter { existing.contains($0) })
            dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
                self?.restoreSelection()
                self?.updateQuickPasteDisplay()
            }
        }
    }

    func setFocusRegion(_ region: FocusRegion) {
        guard region != env.focusRegion else { return }
        env.focusRegion = region
        updateSelectedItemBorder()
    }

    func updateSelectedItemBorder() {
        let focused = env.focusRegion == .collection
        for case let item as FloatingCollectionItem
        in collectionView.visibleItems() {
            item.setFocused(focused)
        }
    }

    func setIsQuickPastePressed(_ pressed: Bool) {
        guard pressed != isQuickPastePressed else { return }
        isQuickPastePressed = pressed
        updateQuickPasteDisplay()
    }

    func resetQuickPasteState() {
        isQuickPastePressed = false
        updateQuickPasteDisplay()
    }

    func setIsPlainTextModifierPressed(_ pressed: Bool) {
        guard pressed != isPlainTextModifierPressed else { return }
        isPlainTextModifierPressed = pressed
        updatePlainTextIndicatorDisplay()
    }

    func selectAndScrollTo(index: Int) {
        selectRow(index)
        scrollTo(index: index)
    }

    func anchorViewForItem(at index: Int) -> NSView {
        let indexPath = IndexPath(item: index, section: 0)
        return (collectionView.item(at: indexPath) as? FloatingCollectionItem)?
            .cardView
            ?? collectionView
    }

    func pasteItem(at index: Int, isAttribute: Bool = true) {
        guard index < dataList.count else { return }
        ClipActionService.shared.paste(
            dataList[index],
            isAttribute: isAttribute,
            checkPermissions: PasteUserDefaults.pasteDirect,
            showTip: !PasteUserDefaults.pasteDirect
        )
    }

    func copyItem(at index: Int) {
        guard index < dataList.count else { return }
        ClipActionService.shared.copy(dataList[index], showTip: true)
    }

    func requestDelete(at index: Int) {
        let items = selectedModels
        if items.count > 1 {
            guard NSAlert.runConfirm(
                title: String(localized: .deleteTitle),
                message: String(localized: .deleteMessage)
            ) else { return }
            let minIndex = collectionView.selectionIndexPaths.map(\.item).min() ?? index
            let countAfterDelete = dataList.count - items.count
            if countAfterDelete > 0 {
                selectedIndex = min(minIndex, countAfterDelete - 1)
            }
            dataStore.deleteItems(items)
            return
        }
        guard index < dataList.count else { return }
        let item = dataList[index]
        guard PasteUserDefaults.delConfirm else {
            dataStore.deleteItems(item)
            return
        }
        if NSAlert.runConfirm(title: String(localized: .deleteTitle), message: String(localized: .deleteMessage)) {
            dataStore.deleteItems(item)
        }
    }

    func openEditWindow(at index: Int) {
        guard index < dataList.count else { return }
        let item = dataList[index]
        guard item.pasteboardType.isText() else { return }
        EditWindowController.shared.openWindow(with: item)
    }

    func activateSearchField(with text: String?) {
        onActivateSearch?(text)
    }

    // MARK: - Multi Selection

    private var isMultiSelect: Bool {
        let modifiers = NSApp.currentEvent?.modifierFlags ?? []
        return modifiers.contains(.command) || modifiers.contains(.shift)
    }

    var selectedModels: [PasteboardModel] {
        collectionView.selectionIndexPaths.sorted()
            .compactMap { path in
                guard path.item < dataList.count else { return nil }
                return dataList[path.item]
            }
    }

}

// MARK: - NSCollectionViewDelegate

extension FloatingHistoryView: NSCollectionViewDelegate {
    func collectionView(
        _: NSCollectionView,
        shouldSelectItemsAt indexPaths: Set<IndexPath>
    ) -> Set<IndexPath> {
        if collectionView.keepsDragSelection { return collectionView.selectionIndexPaths }
        if isMultiSelect {
            if let path = indexPaths.min() {
                selectedIndex = path.item
            }
            return indexPaths
        }
        if let indexPath = indexPaths.first {
            resetSelectIndex(indexPath)
        }
        return [IndexPath(item: selectedIndex, section: 0)]
    }

    func collectionView(
        _: NSCollectionView,
        canDragItemsAt _: Set<IndexPath>,
        with _: NSEvent
    ) -> Bool {
        true
    }

    func collectionView(
        _: NSCollectionView,
        shouldDeselectItemsAt indexPaths: Set<IndexPath>
    ) -> Set<IndexPath> {
        collectionView.keepsDragSelection ? [] : indexPaths
    }

    func collectionView(
        _: NSCollectionView,
        pasteboardWriterForItemAt indexPath: IndexPath
    ) -> (any NSPasteboardWriting)? {
        guard indexPath.item < dataList.count else { return nil }
        return dataList[indexPath.item].writeItem
    }

    func collectionView(
        _: NSCollectionView,
        validateDrop draggingInfo: any NSDraggingInfo,
        proposedIndexPath _: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
        dropOperation _: UnsafeMutablePointer<NSCollectionView.DropOperation>
    ) -> NSDragOperation {
        guard !(draggingInfo.draggingSource is NSCollectionView) else { return [] }
        let pasteboard = draggingInfo.draggingPasteboard
        guard pasteboard.canReadItem(withDataConformingToTypes: Self.dropSupportedTypes) else { return [] }
        dragSourceApp = NSWorkspace.shared.frontmostApplication
        return .copy
    }

    func collectionView(
        _: NSCollectionView,
        acceptDrop draggingInfo: any NSDraggingInfo,
        indexPath _: IndexPath,
        dropOperation _: NSCollectionView.DropOperation
    ) -> Bool {
        let accepted = dataStore.addNewItem(
            draggingInfo.draggingPasteboard,
            sourceApp: dragSourceApp,
            chipId: CategoryChipStore.shared.selectedChipId
        )
        dragSourceApp = nil
        return accepted
    }

    private static let dropSupportedTypes = PasteboardType.supportTypes.map(\.rawValue)

    func resetSelectIndex(_ indexPath: IndexPath) {
        guard indexPath.item < dataList.count else { return }
        selectedIndex = indexPath.item
        collectionView.selectionIndexPaths = [indexPath]
        scrollTo(index: indexPath.item)
    }
}

// MARK: - NSGestureRecognizerDelegate

extension FloatingHistoryView: NSGestureRecognizerDelegate {
    func gestureRecognizer(
        _: NSGestureRecognizer,
        shouldAttemptToRecognizeWith event: NSEvent
    ) -> Bool {
        guard let hitView = window?.contentView?.hitTest(event.locationInWindow)
        else { return true }
        return !hitView.isDescendant(of: collectionView)
    }

    @objc func handleBackgroundClick(_: NSClickGestureRecognizer) {
        setFocusRegion(.collection)
        window?.makeFirstResponder(collectionView)
    }
}

// MARK: - Drag

extension FloatingHistoryView {
    func handleDragMoved(_ screenPoint: NSPoint) {
        guard let window else { return }
        let visibleRect = convert(bounds, to: nil)
        let screenRect = window.convertToScreen(visibleRect)
        if !screenRect.contains(screenPoint),
           ClipFloatingWindowController.shared.isVisible {
            ClipFloatingWindowController.shared.toggleWindow()
        }
    }

    func handleDragEnded(_ screenPoint: NSPoint) {
        guard let window else { return }
        let visibleRect = convert(bounds, to: nil)
        let screenRect = window.convertToScreen(visibleRect)
        guard screenRect.contains(screenPoint) else { return }

        env.suppressResignKey = true
        window.resignKey()
        window.makeKey()
        window.makeFirstResponder(collectionView)
        env.suppressResignKey = false
    }
}
