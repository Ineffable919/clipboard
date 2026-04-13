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

final class ClipMainViewController: NSViewController {
    private let topVM = TopBarViewModel()
    private var selectIndexPath = IndexPath(item: 0, section: 0)
    private var dataList = PasteDataStore.main.dataList
    private var cancellables = Set<AnyCancellable>()
    private let db = PasteDataStore.main
    private let store = CategoryChipStore.shared

    var previousApp: NSRunningApplication?
    var deleteFlag = false
    private var monitorToken: Any?

    // MARK: - Focus

    private var focusRegion: FocusRegion = .collection

    // MARK: - Filter State

    private var selectedTypes: Set<PasteModelType> = []
    private var selectedAppNames: Set<String> = []
    private var selectedDateFilter: DateFilterOption?

    private lazy var effectView: NSView = {
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

    private lazy var contentView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        if #available(macOS 26.0, *) {
            view.layer?.cornerRadius = Const.windowRadis
        }
        view.layer?.masksToBounds = true
        return view
    }()

    private lazy var topBarView: TopBarView = {
        let bar = TopBarView()
        bar.configure(topVM: topVM)
        return bar
    }()

    private lazy var collectionView: ClipCollectionView = {
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
        return collectionView
    }()

    private lazy var scrollView: HorizontalScrollView = {
        let scrollview = HorizontalScrollView()
        scrollview.documentView = collectionView
        scrollview.scrollerStyle = .overlay
        scrollview.autohidesScrollers = true
        scrollview.verticalScrollElasticity = .none
        scrollview.horizontalScrollElasticity = .automatic
        return scrollview
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

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.view.animator().setFrameOrigin(.zero)
        } completionHandler: {
            MainActor.assumeIsolated {
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

extension ClipMainViewController {
    private func initView() {
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
    }
}

// MARK: - Event

extension ClipMainViewController {
    private func initFocus() {
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

    // MARK: - Focus Management

    private func setFocusRegion(_ region: FocusRegion) {
        guard region != focusRegion else { return }
        focusRegion = region
        updateSelectedItemBorder()
    }

    private func updateSelectedItemBorder() {
        (collectionView.item(at: selectIndexPath) as? CollectionViewItem)?
            .setFocused(focusRegion == .collection)
    }
}

// MARK: - Observe

extension ClipMainViewController {
    private func initObserve() {
        dataList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if deleteFlag {
                    deleteFlag = false
                    return
                }
                let changeType = PasteDataStore.main.lastDataChangeType
                if changeType == .reset || changeType == .searchFilter {
                    resetSelectIndex()
                }
                collectionView.reloadData()
            }
            .store(in: &cancellables)

        topBarView.searchField.$text
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                topVM.performSearch()
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
    }
}

extension ClipMainViewController {
    private func performSearch() {
        if topVM.willSearchCriteriaChange() {
            resetSelectIndex()
            collectionView.scroll(.zero)
        }
        topVM.performSearch()
    }

    @objc private func handleContentViewClick(_: NSClickGestureRecognizer) {
        setFocusRegion(.collection)
        view.window?.makeFirstResponder(collectionView)
    }

    private func keyDownEvent(_ event: NSEvent) -> NSEvent? {
        if KeyCode.shouldTriggerSearch(for: event),!topBarView.searchField.isFirstResponder {
            setFocusRegion(.search)
            view.window?.makeFirstResponder(topBarView.searchField)
            // TODO: 帮输入的符号赋值给 topBarView.searchField.text 触发搜索
            return nil
        }

        switch event.keyCode {
        case KeyCode.escape:
            return escapeKeyDown(event)
        case KeyCode.delete:
            return deleteKeyDown(event)
        case KeyCode.return:
            return returnKeyDown(event)
        default:
            return event
        }
    }

    private func escapeKeyDown(_: NSEvent) -> NSEvent? {
        let field = topBarView.searchField
        if field.isFirstResponder {
            if !field.text.isEmpty {
                field.stringValue = ""
            } else {
                view.window?.makeFirstResponder(collectionView)
                setFocusRegion(.collection)
            }
        } else {
            WindowManager.shared.toggleWindow()
        }
        return nil
    }

    private func deleteKeyDown(_ event: NSEvent) -> NSEvent? {
        guard !topBarView.searchField.isFirstResponder else { return event }
        if selectIndexPath.item < dataList.value.count {
            let item = dataList.value[selectIndexPath.item]
            delete(item, indexPath: selectIndexPath)
            return nil
        }
        return event
    }

    private func returnKeyDown(_ event: NSEvent) -> NSEvent? {
        let item = dataList.value[selectIndexPath.item]
        if event.modifierFlags.contains(.shift) {
            pastePlain(item)
        } else {
            paste(item)
        }
        return nil
    }
}

extension ClipMainViewController: NSGestureRecognizerDelegate {
    func gestureRecognizer(_: NSGestureRecognizer,
                           shouldAttemptToRecognizeWith event: NSEvent) -> Bool
    {
        guard let hitView = view.window?.contentView?
            .hitTest(event.locationInWindow)
        else {
            return true
        }
        if hitView.isDescendant(of: collectionView) {
            return false
        }

        if hitView.isDescendant(of: topBarView) {
            return hitView === topBarView
        }

        return true
    }
}

// MARK: - NSCollectionViewDataSource

extension ClipMainViewController: NSCollectionViewDataSource {
    func numberOfSections(in _: NSCollectionView) -> Int {
        1
    }

    func collectionView(_: NSCollectionView, numberOfItemsInSection _: Int) -> Int {
        dataList.value.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: CollectionViewItem.identifier,
            for: indexPath
        )
        guard let cItem = item as? CollectionViewItem else { return item }
        let model = dataList.value[indexPath.item]
        cItem.delegate = self
        cItem.configure(with: model, keyword: topVM.query)
        if selectIndexPath == indexPath {
            cItem.isSelected = true
            cItem.setFocused(focusRegion == .collection)
            collectionView.selectionIndexPaths = [indexPath]
        } else {
            cItem.isSelected = false
        }
        return cItem
    }
}

// MARK: - NSCollectionViewDelegate

extension ClipMainViewController: NSCollectionViewDelegate {
    func collectionView(_: NSCollectionView, shouldSelectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> {
        if let indexPath = indexPaths.first {
            resetSelectIndex(indexPath)
        }
        return [selectIndexPath]
    }

    func collectionView(_: NSCollectionView, canDragItemsAt _: Set<IndexPath>, with _: NSEvent) -> Bool {
        true
    }

    func collectionView(_: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> (any NSPasteboardWriting)? {
        dataList.value[indexPath.item].writeItem
    }

}

extension ClipMainViewController {
    private func resetSelectIndex(
        _ indexPath: IndexPath = IndexPath(item: 0, section: 0)
    ) {
        let zero = IndexPath(item: 0, section: 0)
        if indexPath == zero, selectIndexPath == zero { return }
        collectionView.item(at: selectIndexPath)?.isSelected = false
        selectIndexPath = indexPath
        if !dataList.value.isEmpty {
            collectionView.selectionIndexPaths = [selectIndexPath]
            scrollTo(indexPath: selectIndexPath)
            updateSelectedItemBorder()
        }
    }

    private func scrollTo(indexPath: IndexPath) {
        guard let attrs = collectionView.layoutAttributesForItem(at: indexPath)
        else { return }
        collectionView.scrollToVisible(
            NSRect(
                x: attrs.frame.origin.x - Const.cardSpace,
                y: 0,
                width: attrs.frame.width + Const.cardSpace * 2 + Const.cardSize / 5,
                height: attrs.frame.height
            )
        )
    }
}

// MARK: - CollectionViewItemDelegate

extension ClipMainViewController: CollectionViewItemDelegate {
    var preApp: NSRunningApplication? {
        previousApp
    }

    func itemDidRequestSelect(_ item: CollectionViewItem) {
        if focusRegion != .collection {
            setFocusRegion(.collection)
            view.window?.makeFirstResponder(collectionView)
        }
        guard let indexPath = collectionView.indexPath(for: item),
              indexPath != selectIndexPath else { return }
        resetSelectIndex(indexPath)
    }

    func paste(_ item: PasteboardModel) {
        ClipActionService.shared.paste(item, checkPermissions: PasteUserDefaults.pasteDirect)
    }

    func pastePlain(_ item: PasteboardModel) {
        ClipActionService.shared.paste(
            item,
            isAttribute: false,
            checkPermissions: PasteUserDefaults.pasteDirect
        )
    }

    func copy(_ item: PasteboardModel) {
        ClipActionService.shared.copy(item)
    }

    func edit(_ item: PasteboardModel) {
        EditWindowController.shared.openWindow(with: item)
    }

    func delete(_ item: PasteboardModel, indexPath: IndexPath) {
        deleteFlag = true
        PasteDataStore.main.deleteItems(item)
        collectionView.animator().deleteItems(at: [indexPath])

        let count = dataList.value.count
        guard count > 0 else {
            selectIndexPath = IndexPath(item: 0, section: 0)
            return
        }
        let newIndex = min(indexPath.item, count - 1)
        let newPath = IndexPath(item: newIndex, section: 0)

        collectionView.item(at: selectIndexPath)?.isSelected = false
        selectIndexPath = newPath
        collectionView.selectionIndexPaths = [newPath]
        scrollTo(indexPath: newPath)
        (collectionView.item(at: newPath) as? CollectionViewItem)?.isSelected = true
    }

    func preview(_: PasteboardModel) {
        // TODO: show preview popover
    }
}
