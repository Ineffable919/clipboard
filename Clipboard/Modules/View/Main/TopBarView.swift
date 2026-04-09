//
//  TopBarView.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import SnapKit

final class TopBarView: NSView {
    private let settingBtn = TopBarIconButton(symbolName: "ellipsis")

    private let defaultRow = NSStackView()
    private let searchIconBtn = TopBarIconButton(
        symbolName: "magnifyingglass",
        pointSize: 18
    )
    private let chipScrollView = ChipScrollView()
    private let addChipBtn = TopBarIconButton(symbolName: "plus")

    // MARK: - 搜索模式行

    private let searchRow = NSStackView()
    private let searchField = SearchField()
    private let dotChipScrollView = ChipScrollView()

    // MARK: - State

    private(set) var isSearching = false
    private var viewModel: TopBarViewModel?
    private var observationTask: Task<Void, Never>?

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    deinit { observationTask?.cancel() }

    // MARK: - Public API

    func configure(viewModel: TopBarViewModel) {
        self.viewModel = viewModel
        startObserving(viewModel: viewModel)
        reloadChips()
    }

    func deactivateSearch() {
        guard isSearching else { return }
        isSearching = false
        searchField.stringValue = ""
        viewModel?.clearInput()
        window?.makeFirstResponder(window?.contentView)
        applyMode()
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        setupDefaultRow()
        setupSearchRow()
        setupSettingBtn()
        layoutRows()
        applyMode()
    }

    private func setupDefaultRow() {
        defaultRow.orientation = .horizontal
        defaultRow.spacing = Const.space12
        defaultRow.alignment = .centerY
        defaultRow.distribution = .fill
        defaultRow.setHuggingPriority(.required, for: .horizontal)
        addSubview(defaultRow)

        searchIconBtn.action = { [weak self] in self?.activateSearch() }
        addChipBtn.action = { [weak self] in
            self?.viewModel?.editingNewChip = true
        }

        chipScrollView.setContentHuggingPriority(.required, for: .horizontal)
        chipScrollView.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        defaultRow.addArrangedSubview(searchIconBtn)
        defaultRow.addArrangedSubview(chipScrollView)
        defaultRow.addArrangedSubview(addChipBtn)
    }

    private func setupSearchRow() {
        searchRow.orientation = .horizontal
        searchRow.spacing = Const.space8
        searchRow.alignment = .centerY
        addSubview(searchRow)

        searchField.cell?.controlSize = .large
        searchField.cell?.isScrollable = true
        searchField.cell?.wraps = false
        searchField.cell?.usesSingleLineMode = true
        searchField.setContentHuggingPriority(.required, for: .horizontal)
        searchField.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
        searchField.snp.makeConstraints { make in
            make.width.equalTo(Const.topBarWidth)
        }

        dotChipScrollView.setContentHuggingPriority(.required, for: .horizontal)
        dotChipScrollView.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )

        searchRow.addArrangedSubview(searchField)
        searchRow.addArrangedSubview(dotChipScrollView)

        searchRow.snp.makeConstraints { make in
            make.top.equalToSuperview()
        }

        searchField.delegate = self
    }

    private func setupSettingBtn() {
        settingBtn.action = { /* TODO: 展示设置菜单 */ }
        addSubview(settingBtn)
    }

    private func layoutRows() {
        settingBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Const.space12)
            make.centerY.equalToSuperview()
        }

        defaultRow.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(100)
            make.trailing.lessThanOrEqualTo(settingBtn.snp.leading).offset(
                -Const.space12
            )
            make.centerY.equalToSuperview()
        }

        searchRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - ViewModel Observation

    private func reloadChips() {
        guard let vm = viewModel else { return }

        chipScrollView.reload(
            chips: vm.chips,
            selectedId: vm.selectedChipId,
            dotMode: false
        )
        chipScrollView.onSelectionChanged = { [weak self, weak vm] id in
            vm?.selectedChipId = id
            self?.deactivateSearch()
        }

        dotChipScrollView.reload(
            chips: vm.chips,
            selectedId: vm.selectedChipId,
            dotMode: true
        )
        dotChipScrollView.onSelectionChanged = { [weak self, weak vm] id in
            vm?.selectedChipId = id
            self?.deactivateSearch()
        }
    }

    private func startObserving(viewModel: TopBarViewModel) {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = viewModel.chips
                        _ = viewModel.selectedChipId
                        _ = viewModel.query
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard !Task.isCancelled else { break }
                self?.reloadChips()
                if self?.searchField.stringValue != viewModel.query {
                    self?.searchField.stringValue = viewModel.query
                }
            }
        }
    }

    // MARK: - 模式切换

    private func activateSearch() {
        guard !isSearching else { return }
        isSearching = true
        applyMode()
    }

    private func applyMode() {
        defaultRow.isHidden = isSearching
        searchRow.isHidden = !isSearching

        if isSearching {
            window?.makeFirstResponder(searchField)
        }
    }
}

// MARK: - NSSearchFieldDelegate

extension TopBarView: NSSearchFieldDelegate {
    func controlTextDidChange(_: Notification) {
        viewModel?.query = searchField.stringValue
    }
}
