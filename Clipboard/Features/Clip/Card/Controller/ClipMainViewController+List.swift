import AppKit
import Combine

extension ClipMainViewController {
    func initDiffableDataSource() {
        diffableDataSource = NSCollectionViewDiffableDataSource<
            ClipSection, PasteboardModel
        >(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, model in
            let item = collectionView.makeItem(
                withIdentifier: CollectionViewItem.identifier,
                for: indexPath
            )
            guard let self, let cItem = item as? CollectionViewItem else {
                return item
            }
            cItem.delegate = self
            cItem.configure(with: model, keyword: topVM.query)
            cItem.quickPasteIndex = quickPasteIndex(for: indexPath.item)
            return cItem
        }
    }

    func applySnapshot(items: [PasteboardModel]? = nil, animating: Bool = true, completion: (() -> Void)? = nil) {
        var snapshot = NSDiffableDataSourceSnapshot<ClipSection, PasteboardModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items ?? dataList.value)
        diffableDataSource.apply(snapshot, animatingDifferences: animating) {
            completion?()
        }
        updateEmptyState()
    }

    func displayedModel(at indexPath: IndexPath) -> PasteboardModel? {
        diffableDataSource.itemIdentifier(for: indexPath)
    }

    var displayedItemCount: Int {
        collectionView.numberOfItems(inSection: 0)
    }

    func restoreSelection() {
        guard displayedItemCount > 0 else { return }
        setSelection(to: selectIndexPath)
        updateSelectedItemBorder()
    }
}

// MARK: - Focus

extension ClipMainViewController {
    func initFocus() {
        topBarView.onFocusRegionChange = { [weak self] region in
            self?.setFocusRegion(region)
        }

        topBarView.searchField.onBecomeFirstResponder = { [weak self] in
            self?.setFocusRegion(.search)
        }

        let clickGesture = NSClickGestureRecognizer(
            target: self,
            action: #selector(handleContentViewClick(_:))
        )
        clickGesture.buttonMask = 0x1 // 左键点击
        clickGesture.delegate = self
        contentView.addGestureRecognizer(clickGesture)
    }

    func setFocusRegion(_ region: FocusRegion) {
        guard region != focusRegion else { return }
        focusRegion = region
        if region != .collection {
            isQuickPastePressed = false
            isPlainTextModifierPressed = false
        }
        updateSelectedItemBorder()
        if region == .collection {
            Task { @MainActor [weak self] in
                guard let self, focusRegion == .collection else { return }
                view.window?.makeFirstResponder(collectionView)
            }
        }
    }

    func updateSelectedItemBorder() {
        let isFocused = focusRegion == .collection
        for indexPath in collectionView.selectionIndexPaths {
            (collectionView.item(at: indexPath) as? CollectionViewItem)?
                .setFocused(isFocused)
        }
    }

    @objc func handleContentViewClick(_: NSClickGestureRecognizer) {
        setFocusRegion(.collection)
    }
}

// MARK: - List Presenter

extension ClipMainViewController {
    func initListPresenter() {
        presenter.applyFull = { [weak self] items, animating, completion in
            self?.applySnapshot(items: items, animating: animating, completion: completion)
        }
        presenter.applyReorder = { [weak self] items in self?.applyReorder(items) }
        presenter.appendItems = { [weak self] newItems in
            guard let self else { return }
            var snapshot = diffableDataSource.snapshot()
            let existing = Set(snapshot.itemIdentifiers.map(\.uniqueId))
            let appended = newItems
                .filter { !existing.contains($0.uniqueId) }
            guard !appended.isEmpty else { return }
            snapshot.appendItems(appended, toSection: .main)
            diffableDataSource.apply(snapshot, animatingDifferences: false)
            updateEmptyState()
        }
        presenter.currentSnapshotItems = { [weak self] in
            self?.diffableDataSource.snapshot().itemIdentifiers ?? []
        }
        presenter.resetSelection = { [weak self] in
            self?.resetSelectIndex()
            self?.restoreSelection()
        }
        presenter.restoreSelection = { [weak self] in self?.restoreSelection() }
        presenter.adjustAfterDelete = { [weak self] in self?.adjustSelectionAfterDelete() }
        presenter.updateEmptyState = { [weak self] _ in self?.updateEmptyState() }
        presenter.reconfigureItems = { [weak self] items in
            guard let self else { return }
            let identifiers = diffableDataSource.snapshot().itemIdentifiers
            let indexMap = Dictionary(uniqueKeysWithValues: identifiers.enumerated().map { ($1.uniqueId, $0) })
            for item in items {
                guard let idx = indexMap[item.uniqueId] else { continue }
                (collectionView.item(at: IndexPath(item: idx, section: 0)) as? CollectionViewItem)?
                    .configure(with: item, keyword: topVM.query)
            }
        }

        presenter.previewIsShown = { [weak self] in self?.previewPopover?.isShown == true }
        presenter.closePreview = { [weak self] in self?.closePreviewPopover() }
        presenter.reopenPreview = { [weak self] in self?.updatePreviewForSelectedItem() }

        presenter.isVerticalScroll = false
        presenter.loadMoreThreshold = (Const.cardSize + Const.cardSpace) * 2

        presenter.startObserving(scrollView: scrollView)
    }
}

// MARK: - Observe

extension ClipMainViewController {
    func initObserve() {
        topBarView.searchField.$text
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                topVM.handleQueryChange()
            }
            .store(in: &cancellables)

        store.chipsContentDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                topBarView.reloadChips()
                applySnapshot(animating: false)
                restoreSelection()
            }
            .store(in: &cancellables)

        topVM.filterDidChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                topVM.performSearch()
            }
            .store(in: &cancellables)

        PasteBoard.main.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updatePauseState() }
            .store(in: &cancellables)

        appearanceObservation = view.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, !pauseStack.isHidden else { return }
                view.effectiveAppearance.performAsCurrentDrawingAppearance {
                    pauseStack.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
                }
            }
        }
    }

    private func updatePauseState() {
        let isPaused = PasteBoard.main.isPaused
        pauseStack.isHidden = !isPaused
        if isPaused {
            pauseTimeLabel.stringValue = topVM.formattedRemainingTime
            pauseTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.pauseTimeLabel.stringValue = self?.topVM.formattedRemainingTime ?? ""
                }
        } else {
            pauseTimerCancellable = nil
        }
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            pauseStack.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        }
    }

    private func adjustSelectionAfterDelete() {
        guard displayedItemCount > 0 else { return }
        let safeItem = min(selectIndexPath.item, displayedItemCount - 1)
        let safePath = IndexPath(item: safeItem, section: 0)
        selectIndexPath = safePath
        setSelection(to: safePath)
        scrollTo(indexPath: safePath, animated: false)
        updateSelectedItemBorder()
    }

    func updateEmptyState() {
        emptyStateView.isHidden = !dataList.value.isEmpty
    }
}
