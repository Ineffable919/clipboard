//
//  ClipMainViewController.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import Combine
import CoreFoundation
import SnapKit
import Sparkle

final class ClipMainViewController: NSViewController {
    let topVM = TopBarViewModel()
    let cardVM = CardViewModel()
    let env = AppEnvironment.shared

    var dataList = PasteDataStore.main.dataList
    var cancellables = Set<AnyCancellable>()
    let db = PasteDataStore.main
    let store = CategoryChipStore.shared

    let presenter = ClipListPresenter()

    var monitorToken: Any?
    var flagsMonitorToken: Any?

    // MARK: - Pause Indicator

    private let pauseStack = NSStackView()
    private let pauseTimeLabel = NSTextField(labelWithString: "")
    private let pauseButton = NSButton()
    private var pauseTimerCancellable: AnyCancellable?
    private var appearanceObservation: NSKeyValueObservation?

    // MARK: - Preview

    var previewPopover: ClipPreviewPopover?

    // MARK: - Quick Paste

    var isQuickPastePressed: Bool = false {
        didSet {
            if oldValue != isQuickPastePressed {
                updateQuickPasteDisplay()
            }
        }
    }

    var isPlainTextModifierPressed: Bool = false {
        didSet {
            if oldValue != isPlainTextModifierPressed {
                updatePlainTextIndicatorDisplay()
            }
        }
    }

    // MARK: - Focus

    var focusRegion: FocusRegion {
        get { env.focusRegion }
        set { env.focusRegion = newValue }
    }

    // MARK: - Selection

    var selectIndexPath: IndexPath {
        get { env.selectIndexPath }
        set { env.selectIndexPath = newValue }
    }

    // MARK: - DiffableDataSource

    enum ClipSection { case main }

    var diffableDataSource: NSCollectionViewDiffableDataSource<ClipSection, PasteboardModel>!

    // MARK: - Views

    lazy var bg: BackgroundEffectController = {
        let inner: CGFloat =
            if #available(macOS 26.0, *) { 8.0 } else { 0.0 }
        return BackgroundEffectController(
            cornerRadius: Const.windowRadis,
            innerPadding: inner
        )
    }()

    var effectView: NSView {
        bg.effectView
    }

    var contentView: NSView {
        bg.contentContainer
    }

    lazy var topBarView: TopBarView = {
        let bar = TopBarView()
        bar.configure(topVM: topVM)
        return bar
    }()

    lazy var collectionView: ClipCollectionView = {
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(
            width: Const.cardSize,
            height: Const.cardSize
        )
        flowLayout.minimumInteritemSpacing = Const.cardSpace
        flowLayout.minimumLineSpacing = Const.cardSpace
        flowLayout.scrollDirection = .horizontal
        flowLayout.sectionInset = NSEdgeInsets(
            top: 0,
            left: Const.cardSpace,
            bottom: 0,
            right: Const.cardSpace
        )

        let collectionView = ClipCollectionView()
        collectionView.wantsLayer = true
        collectionView.delegate = self
        collectionView.allowsEmptySelection = false
        collectionView.backgroundColors = [.clear]
        collectionView.collectionViewLayout = flowLayout
        collectionView.isSelectable = true
        collectionView.register(CollectionViewItem.self)
        collectionView.registerForDraggedTypes(PasteboardType.supportTypes)
        collectionView.setDraggingSourceOperationMask(.every, forLocal: true)
        collectionView.setDraggingSourceOperationMask(.copy, forLocal: false)
        collectionView.onMouseDownBeforeSelection = { [weak self] indexPath in
            guard let self, focusRegion != .collection else { return }
            resetSelectIndex(indexPath)
        }
        collectionView.onBecomeFirstResponder = { [weak self] in
            self?.setFocusRegion(.collection)
        }
        collectionView.onDragMoved = { [weak self] screenPoint in
            guard let self, let window = view.window else { return }
            let visibleRect = effectView.convert(effectView.bounds, to: nil)
            let screenRect = window.convertToScreen(visibleRect)
            if !screenRect.contains(screenPoint), WindowManager.shared.isVisible {
                WindowManager.shared.toggleWindow()
            }
        }
        collectionView.onDragEnded = { [weak self] screenPoint in
            guard let self, let window = view.window else { return }
            let visibleRect = effectView.convert(effectView.bounds, to: nil)
            let screenRect = window.convertToScreen(visibleRect)
            guard screenRect.contains(screenPoint) else { return }

            let controller = ClipMainWindowController.shared
            AppEnvironment.shared.suppressResignKey = true
            window.resignKey()
            window.makeKey()
            window.makeFirstResponder(collectionView)
            AppEnvironment.shared.suppressResignKey = false
        }
        return collectionView
    }()

    lazy var scrollView: HorizontalScrollView = {
        let scrollview = HorizontalScrollView()
        scrollview.documentView = collectionView
        scrollview.scrollerStyle = .overlay
        scrollview.autohidesScrollers = true
        scrollview.verticalScrollElasticity = .none
        scrollview.horizontalScrollElasticity = .automatic
        return scrollview
    }()

    lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView(style: .main)
        view.isHidden = true
        return view
    }()
}

// MARK: - 生命周期

extension ClipMainViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        initView()
        initDiffableDataSource()
        initFocus()
        initListPresenter()
        initObserve()
    }

    override func viewDidAppear() {
        view.frame = NSRect(
            x: view.frame.origin.x,
            y: -Const.defaultHeight,
            width: view.frame.width,
            height: Const.defaultHeight
        )

        if focusRegion == .search, !topVM.hasInput {
            topBarView.deactivateSearch()
            setFocusRegion(.collection)
        }

        updateSelectedItemBorder()

        if monitorToken == nil {
            monitorToken = NSEvent.addLocalMonitorForEvents(
                matching: .keyDown,
                handler: keyDownEvent(_:)
            )
        }

        if flagsMonitorToken == nil {
            flagsMonitorToken = NSEvent.addLocalMonitorForEvents(
                matching: .flagsChanged
            ) {
                [weak self] event in
                self?.flagsChangedEvent(event)
            }
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Const.showDuration
            self.view.animator().setFrameOrigin(.zero)
        }
    }

    func resetState() {
        topVM.resetFilterState()
        topBarView.deactivateSearch()
        topBarView.reloadChips()
        db.resetToDefault()
        setFocusRegion(.collection)
        view.window?.makeFirstResponder(collectionView)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        PasteDataStore.main.clearExpiredData()
        if let token = monitorToken {
            NSEvent.removeMonitor(token)
            monitorToken = nil
        }
        if let token = flagsMonitorToken {
            NSEvent.removeMonitor(token)
            flagsMonitorToken = nil
        }
        isQuickPastePressed = false
        isPlainTextModifierPressed = false
    }
}

// MARK: - Layout

extension ClipMainViewController {
    func initView() {
        view.wantsLayer = true
        bg.install(in: view)

        contentView.addSubview(scrollView)
        contentView.addSubview(topBarView)
        contentView.addSubview(emptyStateView)
        setupPauseIndicator()

        scrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
            make.top.equalTo(topBarView.snp.bottom).offset(Const.space10)
        }

        topBarView.snp.makeConstraints { make in
            make.leading.equalTo(contentView.snp.centerX).offset(-225)
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(Const.topBarHeight)
        }

        emptyStateView.snp.makeConstraints { make in
            make.center.equalTo(scrollView)
            make.leading.greaterThanOrEqualTo(scrollView).offset(16)
            make.trailing.lessThanOrEqualTo(scrollView).offset(-16)
        }
    }

    private func setupPauseIndicator() {
        let pauseIcon = NSImageView()
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        pauseIcon.image = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig)
        pauseIcon.contentTintColor = .controlAccentColor
        pauseIcon.snp.makeConstraints { make in
            make.width.height.equalTo(16)
        }

        pauseTimeLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        pauseTimeLabel.textColor = .secondaryLabelColor

        pauseStack.orientation = .horizontal
        pauseStack.alignment = .centerY
        pauseStack.spacing = Const.space6
        pauseStack.edgeInsets = NSEdgeInsets(top: 0, left: Const.space8, bottom: 0, right: Const.space8)
        pauseStack.addArrangedSubview(pauseIcon)
        pauseStack.addArrangedSubview(pauseTimeLabel)
        pauseStack.wantsLayer = true
        pauseStack.layer?.cornerRadius = Const.btnRadius
        pauseStack.layer?.cornerCurve = .continuous
        pauseStack.isHidden = true

        pauseButton.isBordered = false
        pauseButton.title = ""
        pauseButton.target = self
        pauseButton.action = #selector(resumePasteboard)
        contentView.addSubview(pauseButton)
        contentView.addSubview(pauseStack)

        pauseStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Const.space12)
            make.centerY.equalTo(topBarView)
            make.height.equalTo(28)
        }
        pauseButton.snp.makeConstraints { make in
            make.edges.equalTo(pauseStack)
        }
    }

    @objc private func resumePasteboard() {
        topVM.resume()
    }

    private func initDiffableDataSource() {
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

    func applySnapshot(animating: Bool = true, completion: (() -> Void)? = nil) {
        var snapshot = NSDiffableDataSourceSnapshot<ClipSection, PasteboardModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(dataList.value)
        diffableDataSource.apply(snapshot, animatingDifferences: animating) {
            completion?()
        }
        updateEmptyState()
    }

    func restoreSelection() {
        guard !dataList.value.isEmpty else { return }
        collectionView.selectionIndexPaths = [selectIndexPath]
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
        updateSelectedItemBorder()
        if region == .collection {
            Task { @MainActor [weak self] in
                guard let self, focusRegion == .collection else { return }
                view.window?.makeFirstResponder(collectionView)
            }
        }
    }

    func updateSelectedItemBorder() {
        (collectionView.item(at: selectIndexPath) as? CollectionViewItem)?
            .setFocused(focusRegion == .collection)
    }

    @objc func handleContentViewClick(_: NSClickGestureRecognizer) {
        setFocusRegion(.collection)
        view.window?.makeFirstResponder(collectionView)
    }
}

// MARK: - List Presenter

extension ClipMainViewController {
    func initListPresenter() {
        presenter.applyFull = { [weak self] _, animating, completion in
            self?.applySnapshot(animating: animating, completion: completion)
        }
        presenter.appendItems = { [weak self] newItems in
            guard let self else { return }
            var snapshot = diffableDataSource.snapshot()
            snapshot.appendItems(newItems, toSection: .main)
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
            let ids = Set(items.map(\.uniqueId))
            let indexPaths = Set(
                diffableDataSource.snapshot().itemIdentifiers
                    .enumerated()
                    .compactMap { idx, item in
                        ids.contains(item.uniqueId)
                            ? IndexPath(item: idx, section: 0) : nil
                    }
            )
            guard !indexPaths.isEmpty else { return }
            collectionView.reloadItems(at: indexPaths)
        }

        presenter.previewIsShown = { [weak self] in self?.previewPopover?.isShown == true }
        presenter.closePreview = { [weak self] in self?.closePreviewPopover() }
        presenter.reopenPreview = { [weak self] in self?.reopenPreviewForSelectedItem() }

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
        guard !dataList.value.isEmpty else { return }
        let safeItem = min(selectIndexPath.item, dataList.value.count - 1)
        let safePath = IndexPath(item: safeItem, section: 0)
        selectIndexPath = safePath
        collectionView.selectionIndexPaths = [safePath]
        scrollTo(indexPath: safePath)
        updateSelectedItemBorder()
    }

    func updateEmptyState() {
        let isEmpty = dataList.value.isEmpty
        emptyStateView.isHidden = !isEmpty
        scrollView.isHidden = isEmpty
    }
}
