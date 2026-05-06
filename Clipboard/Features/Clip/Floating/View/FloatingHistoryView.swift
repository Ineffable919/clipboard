//
//  FloatingHistoryView.swift
//  Clipboard
//
//  浮动窗口历史记录列表：NSCollectionView + DiffableDataSource
//

import AppKit
import Combine
import SnapKit

// MARK: - FloatingCollectionItem

private final class FloatingCollectionItem: NSCollectionViewItem {
    static let id = NSUserInterfaceItemIdentifier("FloatingCollectionItem")

    private var isFocused = true
    var cardView: FloatingCardRowView {
        view as! FloatingCardRowView
    }

    override func loadView() {
        view = FloatingCardRowView()
    }

    func configure(
        with model: PasteboardModel,
        keyword: String,
        isFocused: Bool,
        quickPasteIndex: Int?
    ) {
        self.isFocused = isFocused
        cardView.configure(
            with: model,
            keyword: keyword,
            isSelected: isSelected,
            isFocused: isFocused,
            quickPasteIndex: quickPasteIndex
        )
    }

    func setFocused(_ focused: Bool) {
        isFocused = focused
        cardView.updateSelection(isSelected: isSelected, isFocused: focused)
    }

    func setQuickPasteIndex(_ index: Int?) {
        cardView.quickPasteIndex = index
    }

    override var isSelected: Bool {
        didSet {
            cardView.updateSelection(
                isSelected: isSelected,
                isFocused: isFocused
            )
        }
    }

    var onPaste: (() -> Void)? {
        get { cardView.onPaste }
        set { cardView.onPaste = newValue }
    }

    var onPastePlainText: (() -> Void)? {
        get { cardView.onPastePlainText }
        set { cardView.onPastePlainText = newValue }
    }

    var onCopy: (() -> Void)? {
        get { cardView.onCopy }
        set { cardView.onCopy = newValue }
    }

    var onDelete: (() -> Void)? {
        get { cardView.onDelete }
        set { cardView.onDelete = newValue }
    }

    var onTogglePreview: (() -> Void)? {
        get { cardView.onTogglePreview }
        set { cardView.onTogglePreview = newValue }
    }
}

// MARK: - FloatingHistoryView

final class FloatingHistoryView: NSView {
    // MARK: - Subviews

    private let scrollView = NSScrollView()
    let collectionView = ClipCollectionView()
    private let collectionLayout = NSCollectionViewFlowLayout()
    private let emptyStateView = EmptyStateView(style: .floating)
    private let scrollInsets = NSEdgeInsets(
        top: FloatConst.headerHeight + FloatConst.cardSpacing
            + Const.selectionBorderWidth,
        left: 0,
        bottom: FloatConst.footerHeight + FloatConst.cardSpacing,
        right: 0
    )

    // MARK: - Data Source

    private var dataSource:
        NSCollectionViewDiffableDataSource<Int, PasteboardModel>!

    // MARK: - State

    private let pd = PasteDataStore.main
    private let env = AppEnvironment.shared
    private weak var topVM: TopBarViewModel?

    var dataList: [PasteboardModel] = []
    var selectedIndex: Int = 0
    var isQuickPastePressed: Bool = false

    var onActivateSearch: ((String?) -> Void)?
    var onTogglePreview: ((Int) -> Void)?

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

    // MARK: - Public API

    func configure(topVM: TopBarViewModel) {
        self.topVM = topVM
        dataList = pd.dataList.value
        env.focusRegion = .collection
        applySnapshot(scrollToTop: true)
        observeData()
        Task { @MainActor [weak self] in
            guard let self else { return }
            window?.makeFirstResponder(collectionView)
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
        guard index < dataList.count else { return }
        let item = dataList[index]

        guard PasteUserDefaults.delConfirm else {
            pd.deleteItems(item)
            return
        }

        AppEnvironment.shared.suppressResignKey = true
        let alert = NSAlert()
        alert.messageText = String(localized: .delete)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: .commonConfirm))
        alert.addButton(withTitle: String(localized: .commonCancel))
        let response = alert.runModal()
        AppEnvironment.shared.suppressResignKey = false

        if response == .alertFirstButtonReturn {
            pd.deleteItems(item)
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

    // MARK: - Setup

    private func setup() {
        wantsLayer = true

        collectionLayout.scrollDirection = .vertical
        collectionLayout.minimumInteritemSpacing = 0
        collectionLayout.minimumLineSpacing = FloatConst.cardSpacing

        collectionLayout.sectionInset = scrollInsets
        collectionLayout.itemSize = NSSize(
            width: FloatConst.cardSize,
            height: FloatConst.cardHeight
        )

        collectionView.collectionViewLayout = collectionLayout
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsEmptySelection = false
        collectionView.allowsMultipleSelection = false
        collectionView.focusRingType = .none
        collectionView.delegate = self
        collectionView.register(
            FloatingCollectionItem.self,
            forItemWithIdentifier: FloatingCollectionItem.id
        )
        collectionView.registerForDraggedTypes(PasteboardType.supportTypes)
        collectionView.setDraggingSourceOperationMask(.every, forLocal: true)
        collectionView.setDraggingSourceOperationMask(.copy, forLocal: false)
        collectionView.onBecomeFirstResponder = { [weak self] in
            self?.setFocusRegion(.collection)
        }
        collectionView.onDragMoved = { [weak self] screenPoint in
            self?.handleDragMoved(screenPoint)
        }
        collectionView.onDragEnded = { [weak self] screenPoint in
            self?.handleDragEnded(screenPoint)
        }

        let clickGesture = NSClickGestureRecognizer(
            target: self,
            action: #selector(handleBackgroundClick(_:))
        )
        clickGesture.buttonMask = 0x1
        clickGesture.delegate = self
        addGestureRecognizer(clickGesture)

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .legacy
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none
        scrollView.documentView = collectionView
        scrollView.scrollerInsets = scrollInsets
        addSubview(scrollView)

        dataSource = NSCollectionViewDiffableDataSource<Int, PasteboardModel>(
            collectionView: collectionView
        ) { [weak self] cv, indexPath, model in
            guard let self else { return nil }
            let item =
                cv.makeItem(
                    withIdentifier: FloatingCollectionItem.id,
                    for: indexPath
                ) as! FloatingCollectionItem
            let row = indexPath.item
            item.configure(
                with: model,
                keyword: topVM?.query ?? "",
                isFocused: env.focusRegion == .collection,
                quickPasteIndex: quickPasteDisplayIndex(for: row)
            )
            item.onPaste = { [weak self] in self?.pasteItem(at: row) }
            item.onPastePlainText = { [weak self] in
                self?.pasteItem(at: row, isAttribute: false)
            }
            item.onCopy = { [weak self] in self?.copyItem(at: row) }
            item.onDelete = { [weak self] in self?.requestDelete(at: row) }
            item.onTogglePreview = { [weak self] in
                self?.onTogglePreview?(row)
            }
            return item
        }

        emptyStateView.isHidden = true
        addSubview(emptyStateView)

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.publisher(
            for: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
        .sink { [weak self] _ in self?.checkLoadMore() }
        .store(in: &cancellables)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Const.space16)
            make.trailing.lessThanOrEqualToSuperview().offset(-Const.space16)
        }
    }

    // MARK: - Data

    private func observeData() {
        pd.dataList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                handleDataChange(pd.lastDataChangeType)
            }
            .store(in: &cancellables)
    }

    private func handleDataChange(_ changeType: PasteDataStore.DataChangeType) {
        let wasEmpty = dataList.isEmpty
        dataList = pd.dataList.value

        switch changeType {
        case .new, .searchFilter, .reset, .moveToFirst:
            applySnapshot(scrollToTop: true)
        case .delete:
            applySnapshot(animating: true)
            adjustSelectionAfterDelete()
        case .loadMore:
            applyLoadMoreSnapshot()
        case .update:
            applySnapshot()
            restoreSelection()
        }

        updateEmptyState()

        if wasEmpty, !dataList.isEmpty {
            selectRow(0)
        }
    }

    private func applySnapshot(
        scrollToTop: Bool = false,
        animating: Bool = false
    ) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, PasteboardModel>()
        snapshot.appendSections([0])
        snapshot.appendItems(dataList, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: animating)
        updateEmptyState()
        if scrollToTop, !dataList.isEmpty {
            selectRow(0)
            collectionView.scroll(.zero)
        } else {
            restoreSelection()
        }
    }

    private func applyLoadMoreSnapshot() {
        var snapshot = dataSource.snapshot()
        let existingIds = Set(snapshot.itemIdentifiers.map(\.uniqueId))
        let newItems = dataList.filter { !existingIds.contains($0.uniqueId) }
        guard !newItems.isEmpty else { return }
        snapshot.appendItems(newItems, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func updateEmptyState() {
        let isEmpty = dataList.isEmpty
        emptyStateView.isHidden = !isEmpty
        scrollView.isHidden = isEmpty
    }

    private func adjustSelectionAfterDelete() {
        guard !dataList.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(selectedIndex, dataList.count - 1)
        restoreSelection()
    }

    private func restoreSelection() {
        guard selectedIndex < dataList.count else { return }
        collectionView.selectionIndexPaths = [
            IndexPath(item: selectedIndex, section: 0),
        ]
    }

    private func selectRow(_ index: Int) {
        guard index >= 0, index < dataList.count else { return }
        selectedIndex = index
        collectionView.selectionIndexPaths = [
            IndexPath(item: index, section: 0),
        ]
    }

    // MARK: - Load More

    private func checkLoadMore() {
        guard pd.hasMoreData, !pd.isLoadingPage else { return }
        let clipView = scrollView.contentView
        let contentHeight = collectionView.frame.height
        let visibleMaxY = clipView.bounds.origin.y + clipView.bounds.height
        let threshold = (FloatConst.cardHeight + FloatConst.cardSpacing) * 5
        guard contentHeight - visibleMaxY < threshold else { return }
        pd.loadNextPage()
    }

    // MARK: - Scroll

    private func event_isARepeat() -> Bool {
        guard let event = NSApp.currentEvent else { return false }
        return event.type == .keyDown && event.isARepeat
    }

    func scrollTo(index: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        guard let attrs = collectionView.layoutAttributesForItem(at: indexPath),
              let clipView = collectionView.enclosingScrollView?.contentView
        else { return }

        let visibleRect = clipView.documentVisibleRect
        let topCover = scrollInsets.top - Const.selectionBorderWidth
        let bottomCover = scrollInsets.bottom
        let peek = FloatConst.cardHeight / 3

        let effectiveMinY = visibleRect.minY + topCover + peek
        let effectiveMaxY = visibleRect.maxY - bottomCover - peek

        var newOriginY = visibleRect.origin.y
        if attrs.frame.minY < effectiveMinY {
            newOriginY = attrs.frame.minY - topCover - peek
        } else if attrs.frame.maxY > effectiveMaxY {
            newOriginY =
                attrs.frame.maxY + bottomCover + peek - visibleRect.height
        } else {
            return
        }

        let maxScrollY = max(
            0,
            collectionView.bounds.height - visibleRect.height
        )
        newOriginY = min(max(0, newOriginY), maxScrollY)

        let scrollView = clipView.enclosingScrollView
        if event_isARepeat() {
            clipView.setBoundsOrigin(NSPoint(x: 0, y: newOriginY))
            scrollView?.reflectScrolledClipView(clipView)
        } else {
            clipView.animator().setBoundsOrigin(NSPoint(x: 0, y: newOriginY))
            scrollView?.reflectScrolledClipView(clipView)
        }
    }

    // MARK: - Quick Paste Display

    private func updateQuickPasteDisplay() {
        for case let item as FloatingCollectionItem
        in collectionView.visibleItems() {
            guard let indexPath = collectionView.indexPath(for: item) else {
                continue
            }
            item.setQuickPasteIndex(quickPasteDisplayIndex(for: indexPath.item))
        }
    }

    private func quickPasteDisplayIndex(for rowIndex: Int) -> Int? {
        guard isQuickPastePressed, rowIndex < 9 else { return nil }
        return rowIndex + 1
    }
}

// MARK: - NSCollectionViewDelegate

extension FloatingHistoryView: NSCollectionViewDelegate {
    func collectionView(
        _: NSCollectionView,
        shouldSelectItemsAt indexPaths: Set<IndexPath>
    ) -> Set<IndexPath> {
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
        pasteboardWriterForItemAt indexPath: IndexPath
    ) -> (any NSPasteboardWriting)? {
        guard indexPath.item < dataList.count else { return nil }
        return dataList[indexPath.item].writeItem
    }

    private func resetSelectIndex(_ indexPath: IndexPath) {
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

    @objc fileprivate func handleBackgroundClick(_: NSClickGestureRecognizer) {
        setFocusRegion(.collection)
        window?.makeFirstResponder(collectionView)
    }
}

// MARK: - Drag

private extension FloatingHistoryView {
    func handleDragMoved(_ screenPoint: NSPoint) {
        guard let window else { return }
        let visibleRect = convert(bounds, to: nil)
        let screenRect = window.convertToScreen(visibleRect)
        if !screenRect.contains(screenPoint),
           ClipFloatingWindowController.shared.isVisible
        {
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
