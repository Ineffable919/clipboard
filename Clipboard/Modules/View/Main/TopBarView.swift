//
//  TopBarView.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit

/// 主窗口顶栏（AppKit）。
///
/// 默认模式：[🔍] [chip 列表] [+]
/// 搜索模式：[SearchField] [● chip 圆点列表]
final class TopBarView: NSView {

    // MARK: - 始终可见

    private let settingBtn = TopBarIconButton(symbolName: "ellipsis")

    // MARK: - 默认模式行

    private let defaultRow = NSStackView()
    private let searchIconBtn = TopBarIconButton(symbolName: "magnifyingglass", pointSize: 18)
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
    required init?(coder: NSCoder) { fatalError() }

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
        defaultRow.spacing = Const.space8
        defaultRow.alignment = .centerY
        defaultRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(defaultRow)

        searchIconBtn.action = { [weak self] in self?.activateSearch() }
        addChipBtn.action = { [weak self] in self?.viewModel?.editingNewChip = true }

        // chipScrollView 填满中间空间（scrollView 内部 contentStack 自然包裹内容）
        chipScrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        chipScrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        defaultRow.addArrangedSubview(searchIconBtn)
        defaultRow.addArrangedSubview(chipScrollView)
        defaultRow.addArrangedSubview(addChipBtn)

        defaultRow.heightAnchor.constraint(equalToConstant: 34).isActive = true
    }

    private func setupSearchRow() {
        searchRow.orientation = .horizontal
        searchRow.spacing = Const.space8
        searchRow.alignment = .centerY
        searchRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchRow)

        searchField.cell?.controlSize = .large
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        dotChipScrollView.setContentHuggingPriority(.required, for: .horizontal)
        dotChipScrollView.setContentCompressionResistancePriority(.required, for: .horizontal)
        dotChipScrollView.widthAnchor.constraint(lessThanOrEqualToConstant: 90).isActive = true

        searchRow.addArrangedSubview(searchField)
        searchRow.addArrangedSubview(dotChipScrollView)

        searchRow.heightAnchor.constraint(equalToConstant: 34).isActive = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(inputChanged),
            name: NSControl.textDidChangeNotification,
            object: searchField
        )
    }

    private func setupSettingBtn() {
        settingBtn.translatesAutoresizingMaskIntoConstraints = false
        settingBtn.action = { /* TODO: 展示设置菜单 */ }
        addSubview(settingBtn)
    }

    private func layoutRows() {
        NSLayoutConstraint.activate([
            settingBtn.trailingAnchor.constraint(equalTo: trailingAnchor),
            settingBtn.centerYAnchor.constraint(equalTo: centerYAnchor),

            defaultRow.centerXAnchor.constraint(equalTo: centerXAnchor),
            defaultRow.widthAnchor.constraint(equalToConstant: Const.topBarWidth),
            defaultRow.centerYAnchor.constraint(equalTo: centerYAnchor),

            searchRow.centerXAnchor.constraint(equalTo: centerXAnchor),
            searchRow.widthAnchor.constraint(equalToConstant: Const.topBarWidth),
            searchRow.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    // MARK: - ViewModel Observation

    private func reloadChips() {
        guard let vm = viewModel else { return }

        chipScrollView.reload(chips: vm.chips, selectedId: vm.selectedChipId, dotMode: false)
        chipScrollView.onSelectionChanged = { [weak vm] id in vm?.selectedChipId = id }

        dotChipScrollView.reload(chips: vm.chips, selectedId: vm.selectedChipId, dotMode: true)
        dotChipScrollView.onSelectionChanged = { [weak vm] id in vm?.selectedChipId = id }
    }

    private func startObserving(viewModel: TopBarViewModel) {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = viewModel.chips
                        _ = viewModel.selectedChipId
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard !Task.isCancelled else { break }
                self?.reloadChips()
            }
        }
    }

    // MARK: - 模式切换

    private func activateSearch() {
        guard !isSearching else { return }
        isSearching = true
        applyMode()
    }

    /// 直接切换两行的显隐，无动画。
    private func applyMode() {
        defaultRow.isHidden = isSearching
        searchRow.isHidden = !isSearching

        if isSearching {
            window?.makeFirstResponder(searchField)
        }
    }

    // MARK: - Input

    @objc private func inputChanged() {
        viewModel?.query = searchField.stringValue
    }
}
