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
        collectionView.setDraggingSourceOperationMask(.every, forLocal: false)
        collectionView.onBecomeFirstResponder = { [weak self] in
            self?.setFocusRegion(.collection)
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

extension ClipMainViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        initView()
        initEvent()
        initObserve()
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

        let needsSearchFocus = focusRegion == .search
        if needsSearchFocus {
            topBarView.searchField.suppressFocusRing = true
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.view.animator().setFrameOrigin(.zero)
        } completionHandler: {
            MainActor.assumeIsolated {
                if needsSearchFocus {
                    self.topBarView.searchField.suppressFocusRing = false
                    self.view.window?.makeFirstResponder(self.topBarView.searchField)
                } else {
                    self.view.window?.makeFirstResponder(self.collectionView)
                }
            }
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        PasteDataStore.main.clearExpiredData()
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

extension ClipMainViewController {
    private func initEvent() {
        topBarView.onFocusRegionChange = { [weak self] region in
            self?.setFocusRegion(region)
        }

        topBarView.searchField.onBecomeFirstResponder = { [weak self] in
            self?.setFocusRegion(.search)
        }
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
                collectionView.reloadData()
                updateSelectedItemBorder()
            }
            .store(in: &cancellables)

        topBarView.searchField.$text
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self else { return }
                topVM.setQuery(text: text)
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

// MARK: - NSCollectionViewDataSource

extension ClipMainViewController: NSCollectionViewDataSource {
    func numberOfSections(in _: NSCollectionView) -> Int {
        1
    }

    func collectionView(
        _: NSCollectionView,
        numberOfItemsInSection _: Int
    ) -> Int {
        dataList.value.count
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: CollectionViewItem.identifier,
            for: indexPath
        )
        guard let cItem = item as? CollectionViewItem else { return item }
        let model = dataList.value[indexPath.item]
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
    func collectionView(
        _: NSCollectionView,
        shouldSelectItemsAt indexPaths: Set<IndexPath>
    ) -> Set<IndexPath> {
        if let indexPath = indexPaths.first {
            resetSelectIndex(indexPath)
        }
        return [selectIndexPath]
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
        dataList.value[indexPath.item].writeItem
    }
}

extension ClipMainViewController {
    private func resetSelectIndex(
        _ indexPath: IndexPath = IndexPath(item: 0, section: 0)
    ) {
        collectionView.item(at: selectIndexPath)?.isSelected = false
        selectIndexPath = indexPath
        if !dataList.value.isEmpty {
            collectionView.selectionIndexPaths = [selectIndexPath]
            scrollTo(indexPath: selectIndexPath)
        }
    }

    private func scrollTo(indexPath: IndexPath) {
        if let item = collectionView.layoutAttributesForItem(at: indexPath) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                collectionView.animator().scrollToVisible(
                    NSRect(
                        x: item.frame.origin.x - Const.cardSpace,
                        y: 0,
                        width: item.frame.width + Const.cardSpace * 2,
                        height: item.frame.height
                    )
                )
            }
        }
    }
}
