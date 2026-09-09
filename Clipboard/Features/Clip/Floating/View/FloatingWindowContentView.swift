//
//  FloatingWindowContentView.swift
//  Clipboard
//
//  浮动窗口主容器：背景 + Header + HistoryView + Footer 的布局
//

import AppKit
import Combine
import SnapKit

final class FloatingWindowContentView: NSView {
    // MARK: - Subviews

    private let bg = BackgroundEffectController(cornerRadius: 0)
    let headerView = FloatingHeaderView()
    let historyView = FloatingHistoryView()
    let footerView = FloatingFooterView()

    // MARK: - State

    let topVM = TopBarViewModel()
    private(set) var displayMode: FloatingDisplayMode = .standard
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

    func setDisplayMode(_ mode: FloatingDisplayMode) {
        guard displayMode != mode else { return }
        displayMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: PrefKey.floatMode.rawValue)
        headerView.setDisplayMode(mode)
        footerView.displayMode = mode
        headerView.snp.updateConstraints { $0.height.equalTo(mode.headerHeight) }
        footerView.snp.updateConstraints { $0.height.equalTo(mode.footerHeight) }
        historyView.setDisplayMode(mode)

        if let window {
            window.contentView?.layer?.cornerRadius = mode.windowRadius
            var frame = window.frame
            frame.origin.y = frame.maxY - mode.windowSize.height
            frame.size = mode.windowSize
            if let screen = window.screen {
                frame.origin.y = max(screen.visibleFrame.minY, frame.origin.y)
            }
            window.setFrame(frame, display: true)
        }
        layoutSubtreeIfNeeded()
        historyView.scrollTo(index: historyView.selectedIndex)
    }

    func resetState() {
        topVM.resetFilterState()
        headerView.clearSearch()
        headerView.reloadChips()
        PasteDataStore.main.resetToDefault()
        historyView.setFocusRegion(.collection)
        window?.makeFirstResponder(historyView.collectionView)
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true

        bg.install(in: self)
        let container = bg.contentContainer

        container.addSubview(historyView)
        container.addSubview(headerView)
        container.addSubview(footerView)

        headerView.configure(topVM: topVM)
        historyView.configure(topVM: topVM)
        footerView.configure(topVM: topVM)
        footerView.onDisplayModeChanged = { [weak self] mode in
            self?.setDisplayMode(mode)
        }

        historyView.onActivateSearch = { [weak self] text in
            self?.headerView.activateSearch(with: text)
        }
        historyView.onCreateChip = { [weak self] model in
            self?.headerView.startCreatingChip(pinModel: model)
        }
        headerView.onSearchBecameFirstResponder = { [weak self] in
            self?.historyView.setFocusRegion(.search)
        }
        headerView.onChipEditingFocusChange = { [weak self] focused in
            self?.historyView.setFocusRegion(focused ? .chipEditing : .collection)
        }

        PasteDataStore.main.dataList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.footerView.updateCount()
            }
            .store(in: &cancellables)

        headerView.searchField.$text
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self else { return }
                topVM.setQuery(text: text)
                topVM.handleQueryChange()
            }
            .store(in: &cancellables)

        topVM.filterDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                topVM.performSearch()
                headerView.updateChipSelection()
            }
            .store(in: &cancellables)

        layoutSubviews()
    }

    private func layoutSubviews() {
        let container = bg.contentContainer

        historyView.snp.makeConstraints { $0.edges.equalTo(container) }

        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(container)
            make.height.equalTo(FloatConst.headerHeight)
        }

        footerView.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalTo(container)
            make.height.equalTo(FloatConst.footerHeight)
        }
    }
}
