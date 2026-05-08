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

    private let bg = BackgroundEffectController(cornerRadius: Const.radius)
    let headerView = FloatingHeaderView()
    let historyView = FloatingHistoryView()
    let footerView = FloatingFooterView()

    // MARK: - State

    let topVM = TopBarViewModel()
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

        historyView.onActivateSearch = { [weak self] text in
            self?.headerView.activateSearch(with: text)
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
        }

        footerView.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalTo(container)
            make.height.equalTo(FloatConst.footerHeight)
        }
    }
}
