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
    let dataStore = PasteDataStore.main
    let store = CategoryChipStore.shared

    let presenter = ClipListPresenter()

    var monitorToken: Any?
    var flagsMonitorToken: Any?
    var dragSourceApp: NSRunningApplication?
    var draggedIDs: [Int64] = []
    var dragFilterRevision = 0
    var restoringSelection = false

    // MARK: - Pause Indicator

    let pauseStack = NSStackView()
    let pauseTimeLabel = NSTextField(labelWithString: "")
    let pauseButton = NSButton()
    var pauseTimerCancellable: AnyCancellable?
    var appearanceObservation: NSKeyValueObservation?

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

    lazy var backdrop: BackgroundEffectController = {
        let inner: CGFloat =
            if #available(macOS 26.0, *) {
                8.0
            } else {
                0.0
            }
        let slides = if #available(macOS 15.0, *) { true } else { false }
        return BackgroundEffectController(
            cornerRadius: Const.windowRadis,
            innerPadding: inner,
            slides: slides
        )
    }()

    var effectView: NSView {
        backdrop.effectView
    }

    var contentView: NSView {
        backdrop.contentContainer
    }

    lazy var topBarView: TopBarView = {
        let bar = TopBarView()
        bar.configure(topVM: topVM)
        return bar
    }()

    lazy var collectionView: ClipCollectionView = {
        let flowLayout = CardLayout()
        flowLayout.itemSize = NSSize(
            width: Const.cardSize,
            height: Const.cardSize
        )
        flowLayout.minimumInteritemSpacing = Const.cardSpace
        flowLayout.minimumLineSpacing = Const.cardSpace
        flowLayout.scrollDirection = .horizontal
        flowLayout.sectionInset = NSEdgeInsets(
            top: 0,
            left: Const.space20,
            bottom: 0,
            right: Const.space20
        )

        let collectionView = ClipCollectionView()
        collectionView.wantsLayer = true
        collectionView.delegate = self
        collectionView.allowsEmptySelection = false
        collectionView.allowsMultipleSelection = true
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
        collectionView.onShiftClick = { [weak self] clickedPath in
            guard let self else { return }
            setFocusRegion(.collection)
            let lower = min(selectIndexPath.item, clickedPath.item)
            let upper = max(selectIndexPath.item, clickedPath.item)
            let paths = Set((lower ... upper).map { IndexPath(item: $0, section: 0) })
            collectionView.selectionIndexPaths = paths
            scrollTo(indexPath: clickedPath)
        }
        collectionView.onCollapseToSingle = { [weak self] indexPath in
            guard let self else { return }
            resetSelectIndex(indexPath)
            setFocusRegion(.collection)
        }
        collectionView.onDragMoved = { [weak self] screenPoint in
            guard let self, let window = view.window else { return }
            let visibleRect = effectView.convert(effectView.bounds, to: nil)
            let screenRect = window.convertToScreen(visibleRect)
            if !screenRect.contains(screenPoint), WindowManager.shared.isVisible {
                ClipMainWindowController.shared.dismiss()
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

    lazy var dropOverlayView: ClipDropOverlayView = {
        let view = ClipDropOverlayView()
        view.canAcceptDrag = { [weak self] draggingInfo in
            self?.canAcceptExternalDrop(draggingInfo) == true
        }
        view.acceptDrag = { [weak self] draggingInfo in
            self?.acceptExternalDrop(draggingInfo) == true
        }
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

        if topBarView.isSearching, !topVM.hasInput {
            topBarView.deactivateSearch()
            setFocusRegion(.collection)
        } else if focusRegion == .collection {
            view.window?.makeFirstResponder(collectionView)
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
            ) { [weak self] event in
                self?.flagsChangedEvent(event)
            }
        }
    }

    func setSearchFocusRingSuppressed(_ suppressed: Bool) {
        topBarView.searchField.setFocusRingSuppressed(suppressed)
    }

    func resetState() {
        topVM.resetFilterState()
        topBarView.deactivateSearch()
        topBarView.reloadChips()
        dataStore.resetToDefault()
        setFocusRegion(.collection)
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
        dropOverlayView.resetDragState()
    }
}

// MARK: - Layout

extension ClipMainViewController {
    func initView() {
        view.wantsLayer = true
        backdrop.install(in: view)

        contentView.addSubview(scrollView)
        contentView.addSubview(topBarView)
        contentView.addSubview(emptyStateView)
        contentView.addSubview(dropOverlayView)
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

        dropOverlayView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView)
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

}
