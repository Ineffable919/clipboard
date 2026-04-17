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
        collectionView.dataSource = self
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
        initFocus()
        initObserve()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if focusRegion != .search {
            topBarView.searchField.acceptsFocus = false
        }
    }

    override func viewDidAppear() {
        view.frame = NSRect(
            x: view.frame.origin.x,
            y: -Const.defaultHeight,
            width: view.frame.width,
            height: Const.defaultHeight
        )

        if focusRegion == .search, topBarView.searchField.stringValue.isEmpty {
            topBarView.deactivateSearch()
            focusRegion = .collection
        }

        updateSelectedItemBorder()

        if monitorToken == nil {
            monitorToken = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: keyDownEvent(_:))
        }

        if focusRegion == .search {
            topBarView.searchField.suppressFocusRing = true
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Const.showDuration
            self.view.animator().setFrameOrigin(.zero)
        }) {
            MainActor.assumeIsolated {
                ClipMainWindowController.shared.isAnimating = false

                if self.topBarView.isSearching {
                    self.topBarView.searchField.acceptsFocus = true
                }

                if self.focusRegion == .search {
                    self.topBarView.searchField.suppressFocusRing = false
                    self.view.window?.makeFirstResponder(
                        self.topBarView.searchField
                    )
                } else {
                    self.view.window?.makeFirstResponder(self.collectionView)
                }
                self.updateSelectedItemBorder()
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

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleContentViewClick(_:)))
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
            .filter { [weak self] _ in self?.cardVM.deleteFlag == false }
            .sink { [weak self] _ in
                guard let self else { return }
                cardVM.deleteFlag = false
                collectionView.reloadData()
                updateEmptyState()
                if db.lastDataChangeType == .new, selectIndexPath.item != 0 {
                    resetSelectIndex()
                }
            }
            .store(in: &cancellables)

        topBarView.searchField.$text
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                performSearch()
            }
            .store(in: &cancellables)

        store.$selectedChipId
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                performSearch()
            }
            .store(in: &cancellables)

        store.chipsContentDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
    }

    func performSearch() {
        resetSelectIndex()
        topVM.performSearch()
        updateEmptyState()
    }

    func updateEmptyState() {
        let isEmpty = dataList.value.isEmpty
        emptyStateView.isHidden = !isEmpty
        scrollView.isHidden = isEmpty
    }
}
