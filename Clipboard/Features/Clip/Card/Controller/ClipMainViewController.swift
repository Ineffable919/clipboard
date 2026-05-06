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

    var monitorToken: Any?
    var flagsMonitorToken: Any?

    // MARK: - Pause Indicator

    private let pauseStack = NSStackView()
    private let pauseTimeLabel = NSTextField(labelWithString: "")
    private let pauseButton = NSButton()
    private var pauseTimer: Timer?
    private var appearanceObservation: NSKeyValueObservation?

    var lastBackgroundType: Int = 0
    var lastGlassMaterial: Int = 2

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

    lazy var effectView: NSView = buildEffectView()

    private func buildEffectView() -> NSView {
        if #available(macOS 26.0, *) {
            let bgType = BackgroundType(rawValue: PasteUserDefaults.backgroundType) ?? .liquid
            if bgType == .liquid {
                let glassView = NSGlassEffectView()
                glassView.frame = view.frame
                glassView.cornerRadius = Const.windowRadis
                glassView.contentView = contentView
                return glassView
            }
        }

        let visualEffect = NSVisualEffectView()
        visualEffect.wantsLayer = true
        visualEffect.frame = view.frame
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        if #available(macOS 26.0, *) {
            visualEffect.layer?.cornerRadius = Const.windowRadis
        }
        let material = GlassMaterial(rawValue: PasteUserDefaults.glassMaterial) ?? .regular
        visualEffect.material = material.nsMaterial
        return visualEffect
    }

    func rebuildEffectView() {
        contentView.removeFromSuperview()

        let oldView = effectView
        oldView.removeFromSuperview()

        let newView = buildEffectView()
        effectView = newView

        view.addSubview(newView)

        if newView is NSVisualEffectView {
            newView.addSubview(contentView)
            contentView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        let inner: CGFloat =
            if #available(macOS 26.0, *) {
                8.0
            } else { 0.0 }

        newView.snp.makeConstraints { make in
            make.leading.equalTo(inner)
            make.trailing.equalTo(-inner)
            make.top.equalToSuperview()
            make.bottom.equalTo(-inner)
        }

        view.layoutSubtreeIfNeeded()
    }

    lazy var contentView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        if #available(macOS 26.0, *) {
            view.layer?.cornerRadius = Const.windowRadis
        }
        view.layer?.masksToBounds = true
        return view
    }()

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
            focusRegion = .collection
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

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Const.showDuration
            self.view.animator().setFrameOrigin(.zero)
        }) {
            Task { @MainActor in
                ClipMainWindowController.shared.isAnimating = false
            }
        }
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
    }
}

// MARK: - Layout

extension ClipMainViewController {
    func initView() {
        view.wantsLayer = true
        view.addSubview(effectView)
        if effectView is NSVisualEffectView {
            effectView.addSubview(contentView)
            contentView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        contentView.addSubview(scrollView)
        contentView.addSubview(topBarView)
        contentView.addSubview(emptyStateView)
        setupPauseIndicator()

        let inner: CGFloat =
            if #available(macOS 26.0, *) {
                8.0
            } else { 0.0 }

        effectView.snp.makeConstraints { make in
            make.leading.equalTo(inner)
            make.trailing.equalTo(-inner)
            make.top.equalToSuperview()
            make.bottom.equalTo(-inner)
        }

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

        pauseTimeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
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

    func applyLoadMoreSnapshot() {
        var snapshot = diffableDataSource.snapshot()
        let existingIds = Set(snapshot.itemIdentifiers.map(\.uniqueId))
        let newItems = dataList.value.filter {
            !existingIds.contains($0.uniqueId)
        }
        guard !newItems.isEmpty else {
            updateEmptyState()
            return
        }
        snapshot.appendItems(newItems, toSection: .main)
        diffableDataSource.apply(snapshot, animatingDifferences: false)
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

// MARK: - Observe

extension ClipMainViewController {
    func initObserve() {
        dataList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                handleDataChange(db.lastDataChangeType)
            }
            .store(in: &cancellables)

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

        scrollView.contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.publisher(
            for: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        .throttle(
            for: .milliseconds(200),
            scheduler: DispatchQueue.main,
            latest: true
        )
        .sink { [weak self] _ in
            self?.checkLoadMore()
        }
        .store(in: &cancellables)

        Publishers.Merge(
            UserDefaults.standard.publisher(for: \.backgroundType).map { _ in () },
            UserDefaults.standard.publisher(for: \.glassMaterial).map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self else { return }
            handleEffectViewSettingsChange()
        }
        .store(in: &cancellables)

        lastBackgroundType = PasteUserDefaults.backgroundType
        lastGlassMaterial = PasteUserDefaults.glassMaterial

        topVM.$isPaused
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
        let isPaused = topVM.isPaused
        pauseStack.isHidden = !isPaused
        if isPaused {
            pauseTimeLabel.stringValue = topVM.formattedRemainingTime
            startPauseTimer()
        } else {
            stopPauseTimer()
        }
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            pauseStack.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        }
    }

    private func startPauseTimer() {
        guard pauseTimer == nil else { return }
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pauseTimeLabel.stringValue = self?.topVM.formattedRemainingTime ?? ""
            }
        }
        RunLoop.main.add(pauseTimer!, forMode: .common)
    }

    private func stopPauseTimer() {
        pauseTimer?.invalidate()
        pauseTimer = nil
    }

    private func handleEffectViewSettingsChange() {
        let currentBgType = PasteUserDefaults.backgroundType
        let currentMaterial = PasteUserDefaults.glassMaterial

        guard currentBgType != lastBackgroundType || currentMaterial != lastGlassMaterial else {
            return
        }

        let bgTypeChanged = currentBgType != lastBackgroundType
        lastBackgroundType = currentBgType
        lastGlassMaterial = currentMaterial

        if !bgTypeChanged, let visualEffect = effectView as? NSVisualEffectView {
            let material = GlassMaterial(rawValue: currentMaterial) ?? .regular
            visualEffect.material = material.nsMaterial
        } else {
            rebuildEffectView()
        }
    }

    ///  UI 刷新策略
    private func handleDataChange(_ changeType: PasteDataStore.DataChangeType) {
        let shouldDismissPreview = changeType != .loadMore && changeType != .update
        let wasShowingPreview = previewPopover?.isShown == true

        if shouldDismissPreview, wasShowingPreview {
            closePreviewPopover()
        }

        switch changeType {
        case .delete:
            applySnapshot(animating: true) { [weak self] in
                self?.adjustSelectionAfterDelete()
            }
        case .new, .searchFilter, .moveToFirst, .reset:
            applySnapshot(animating: false)
            resetSelectIndex()
            restoreSelection()
        case .loadMore:
            applyLoadMoreSnapshot()
        case .update:
            applySnapshot(animating: false)
            restoreSelection()
        }

        if changeType == .new || changeType == .update, wasShowingPreview {
            reopenPreviewForSelectedItem()
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

    private func checkLoadMore() {
        guard db.hasMoreData, !db.isLoadingPage else { return }

        let clipView = scrollView.contentView
        let contentWidth = collectionView.frame.width
        let visibleMaxX = clipView.bounds.origin.x + clipView.bounds.width
        let threshold = (Const.cardSize + Const.cardSpace) * 2

        guard contentWidth - visibleMaxX < threshold else { return }
        db.loadNextPage()
    }
}
