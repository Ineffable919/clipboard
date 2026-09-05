import AppKit
import SnapKit

// MARK: - Setup & Data

extension FloatingHistoryView {
    func setup() {
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
        collectionView.allowsMultipleSelection = true
        collectionView.focusRingType = .none
        collectionView.delegate = self
        collectionView.register(
            FloatingCollectionItem.self,
            forItemWithIdentifier: FloatingCollectionItem.id
        )
        collectionView.registerForDraggedTypes(PasteboardType.supportTypes)
        collectionView.setDraggingSourceOperationMask(.every, forLocal: true)
        collectionView.setDraggingSourceOperationMask(.copy, forLocal: false)
        setupCallbacks()

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none
        scrollView.documentView = collectionView
        scrollView.scrollerInsets = scrollInsets
        addSubview(scrollView)

        setupSource()

        emptyStateView.isHidden = true
        addSubview(emptyStateView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Const.space16)
            make.trailing.lessThanOrEqualToSuperview().offset(-Const.space16)
        }
    }

    private func setupCallbacks() {
        let clickGesture = NSClickGestureRecognizer(
            target: self,
            action: #selector(handleBackgroundClick(_:))
        )
        clickGesture.buttonMask = 0x1
        clickGesture.delegate = self
        addGestureRecognizer(clickGesture)

        collectionView.onBecomeFirstResponder = { [weak self] in
            self?.setFocusRegion(.collection)
        }
        collectionView.onDragMoved = { [weak self] screenPoint in
            self?.handleDragMoved(screenPoint)
        }
        collectionView.onDragEnded = { [weak self] screenPoint in
            self?.handleDragEnded(screenPoint)
        }
        collectionView.onShiftClick = { [weak self] clickedPath in
            guard let self else { return }
            let lower = min(selectedIndex, clickedPath.item)
            let upper = max(selectedIndex, clickedPath.item)
            collectionView.selectionIndexPaths = Set((lower ... upper).map { IndexPath(item: $0, section: 0) })
            scrollTo(index: clickedPath.item)
        }
        collectionView.onCollapseToSingle = { [weak self] indexPath in
            guard let self else { return }
            resetSelectIndex(indexPath)
        }
    }

    private func setupSource() {
        dataSource = NSCollectionViewDiffableDataSource<Int, PasteboardModel>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, model in
            guard let self else { return nil }
            guard let item = collectionView.makeItem(
                withIdentifier: FloatingCollectionItem.id,
                for: indexPath
            ) as? FloatingCollectionItem else { return nil }
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
            item.onEdit = { [weak self] in self?.openEditWindow(at: row) }
            item.onDelete = { [weak self] in self?.requestDelete(at: row) }
            item.onTogglePreview = { [weak self] in self?.onTogglePreview?(row) }
            item.onAssignToChip = { [weak self] chipId in
                guard let self, row < dataList.count else { return }
                _ = topVM?.assignModelToChip(model: dataList[row], chipId: chipId)
            }
            item.onCreateChip = { [weak self] model in
                self?.onCreateChip?(model)
            }
            return item
        }
    }

    // MARK: - Data

    func applySnapshot(animating: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, PasteboardModel>()
        snapshot.appendSections([0])
        snapshot.appendItems(dataList, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: animating)
    }

    func resetToFirst() {
        guard !dataList.isEmpty else { return }
        selectRow(0)
        collectionView.scroll(.zero)
    }

    func adjustSelectionAfterDelete() {
        guard !dataList.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(selectedIndex, dataList.count - 1)
        restoreSelection()
        scrollTo(index: selectedIndex)
    }

    func restoreSelection() {
        guard selectedIndex < dataList.count else { return }
        collectionView.selectionIndexPaths = [
            IndexPath(item: selectedIndex, section: 0)
        ]
    }

    func selectRow(_ index: Int) {
        guard index >= 0, index < dataList.count else { return }
        selectedIndex = index
        collectionView.selectionIndexPaths = [
            IndexPath(item: index, section: 0)
        ]
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

    func updateQuickPasteDisplay() {
        for case let item as FloatingCollectionItem
        in collectionView.visibleItems() {
            guard let indexPath = collectionView.indexPath(for: item) else {
                continue
            }
            item.setQuickPasteIndex(quickPasteDisplayIndex(for: indexPath.item))
        }
    }

    func quickPasteDisplayIndex(for rowIndex: Int) -> Int? {
        guard isQuickPastePressed, rowIndex < 9 else { return nil }
        return rowIndex + 1
    }

    func updatePlainTextIndicatorDisplay() {
        for case let item as FloatingCollectionItem in collectionView.visibleItems() {
            item.setShowPlainTextIndicator(isPlainTextModifierPressed)
        }
    }
}
