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

    // MARK: - Preview

    private(set) lazy var previewManager: ClipPreviewManager = .init(
        onFocusChange: { [weak self] region in
            self?.setFocusRegion(region)
        },
        onPopoverClose: { [weak self] in
            guard let self else { return }
            guard focusRegion == .popover else { return }
            setFocusRegion(.collection)
            view.window?.makeFirstResponder(collectionView)
        },
        onRestoreFirstResponder: { [weak self] in
            guard let self else { return }
            view.window?.makeFirstResponder(collectionView)
        }
    )

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

    lazy var effectView: NSView = {
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.frame = view.frame
            glassView.cornerRadius = Const.windowRadis
            glassView.contentView = contentView
            return glassView
        } else {
            let effectView = NSVisualEffectView()
            effectView.wantsLayer = true
            effectView.frame = view.frame
            effectView.state = .active
            effectView.blendingMode = .behindWindow
            return effectView
        }
    }()

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

    private func initDiffableDataSource() {
        diffableDataSource = NSCollectionViewDiffableDataSource<ClipSection, PasteboardModel>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, model in
            let item = collectionView.makeItem(
                withIdentifier: CollectionViewItem.identifier,
                for: indexPath
            )
            guard let self, let cItem = item as? CollectionViewItem else { return item }
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
        let newItems = dataList.value.filter { !existingIds.contains($0.uniqueId) }
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

                let changeType = db.lastDataChangeType

                switch changeType {
                case .delete:
                    applySnapshot(animating: true) { [weak self] in
                        guard let self, !dataList.value.isEmpty else { return }
                        let safeItem = min(selectIndexPath.item, dataList.value.count - 1)
                        let safePath = IndexPath(item: safeItem, section: 0)
                        selectIndexPath = safePath
                        collectionView.selectionIndexPaths = [safePath]
                        scrollTo(indexPath: safePath)
                        updateSelectedItemBorder()
                    }
                case .new:
                    // 新卡片插入后 selectedIndex 会偏移，popover anchor 会错位，直接关闭
                    previewManager.close()
                    applySnapshot(animating: false)
                    resetSelectIndex()
                    restoreSelection()
                case .searchFilter:
                    applySnapshot(animating: false)
                    resetSelectIndex()
                    restoreSelection()
                case .moveToFirst:
                    // 同 .new，卡片顺序变化导致 anchor 错位
                    previewManager.close()
                    applySnapshot(animating: false)
                    resetSelectIndex()
                    restoreSelection()
                case .loadMore:
                    applyLoadMoreSnapshot()
                case .reset:
                    applySnapshot(animating: false)
                    resetSelectIndex()
                    restoreSelection()
                case .update:
                    applySnapshot(animating: false)
                    restoreSelection()
                }
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

        store.$selectedChipId
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                topVM.performSearch()
            }
            .store(in: &cancellables)

        store.chipsContentDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                applySnapshot(animating: false)
            }
            .store(in: &cancellables)

        topVM.filterDidChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                topVM.performSearch()
            }
            .store(in: &cancellables)
    }

    func updateEmptyState() {
        let isEmpty = dataList.value.isEmpty
        emptyStateView.isHidden = !isEmpty
        scrollView.isHidden = isEmpty
    }
}
