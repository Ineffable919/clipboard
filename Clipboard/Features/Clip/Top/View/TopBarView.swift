//
//  TopBarView.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import Combine
import SnapKit

final class TopBarView: NSView {
    private let chipRowHeight: CGFloat = 44

    private let settingBtn = TopBarIconButton(
        symbolName: "ellipsis",
        pointSize: 17
    )

    private let defaultRow = NSStackView()
    private let searchIconBtn = TopBarIconButton(
        symbolName: "magnifyingglass",
        pointSize: 18
    )
    private let chipScrollView = ChipScrollView()
    private let addChipBtn = TopBarIconButton(symbolName: "plus")

    // MARK: - 搜索模式行

    private let searchRow = NSStackView()
    let searchField = SearchField()
    private let dotChipScrollView = ChipScrollView()

    // MARK: - Popover

    var filterPopover: FilterPopover?
    enum FilterPopoverCloseDestination {
        case search
        case collection
    }

    var explicitFilterPopoverCloseDestination: FilterPopoverCloseDestination?
    var filterPopoverMouseMonitor: Any?

    // MARK: - Callbacks

    var onFocusRegionChange: ((FocusRegion) -> Void)?

    // MARK: - State

    private(set) var isSearching = false
    private(set) var topVM: TopBarViewModel?
    var cancellables = Set<AnyCancellable>()
    var shouldSkipNextTokenSync = false
    private var searchFieldWidth = Const.searchFieldMinWidth
    private var searchFieldWidthConstraint: Constraint?
    private static var _cachedAppSuggestions: [AppSuggestionInfo]?
    var appSuggestionsLoadingTask: Task<Void, Never>?

    var cachedAppSuggestions: [AppSuggestionInfo]? {
        get { Self._cachedAppSuggestions }
        set { Self._cachedAppSuggestions = newValue }
    }

    lazy var chipController = TopBarChipController(
        topVM: topVM,
        chipScrollView: chipScrollView,
        dotChipScrollView: dotChipScrollView
    )

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateSearchFieldWidth()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Public API

    func configure(topVM: TopBarViewModel) {
        self.topVM = topVM

        filterPopover = FilterPopover(viewModel: topVM)
        filterPopover?.onWillClose = { [weak self] in
            self?.handlePopoverWillClose()
        }
        filterPopover?.onDidClose = { [weak self] in
            self?.handlePopoverDidClose()
        }

        chipController.updateViewModel(topVM)
        chipController.onReloadNeeded = { [weak self] in
            self?.chipController.reloadChips()
        }
        chipController.onFocusRegionChange = { [weak self] region in
            self?.onFocusRegionChange?(region)
        }
        chipController.onDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        reloadChips()
        setupTokenSync()
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
        observeUpdateBadge()
    }

    private func setupDefaultRow() {
        defaultRow.wantsLayer = true
        defaultRow.orientation = .horizontal
        defaultRow.spacing = Const.space12
        defaultRow.alignment = .centerY
        defaultRow.distribution = .fill
        defaultRow.setHuggingPriority(.required, for: .horizontal)
        addSubview(defaultRow)

        searchIconBtn.action = { [weak self] in self?.activateSearch() }
        addChipBtn.action = { [weak self] in
            self?.chipController.startCreatingChip()
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
        searchRow.wantsLayer = true
        searchRow.orientation = .horizontal
        searchRow.spacing = Const.space8
        searchRow.alignment = .centerY
        addSubview(searchRow)

        searchField.placeholderString = String(localized: .search)
        searchField.snp.makeConstraints { make in
            searchFieldWidthConstraint = make.width.equalTo(searchFieldWidth).constraint
            make.height.equalTo(32)
        }

        searchField.onResignFirstResponder = { [weak self] in
            guard let self, let topVM else { return }

            if filterPopover?.isShown == true {
                return
            }

            if isSearching, !topVM.hasInput {
                deactivateSearch()
                onFocusRegionChange?(.collection)
            }
        }

        searchField.onTextChanged = { [weak self] text in
            guard let self else { return }
            topVM?.setQuery(text: text)
        }

        searchField.onSuggestionsNeeded = { [weak self] query in
            self?.buildSuggestions(query: query) ?? []
        }

        searchField.onSuggestionSelected = { [weak self] item in
            self?.handleSuggestionSelected(item)
        }

        searchField.onFilterButtonTapped = { [weak self] in
            self?.togglePopover()
        }

        searchField.onTokenDeleted = { [weak self] tag in
            Task { @MainActor [weak self] in
                self?.handleTokenDeletedFromSearchField(tag)
            }
        }

        searchField.onClearAllFilters = { [weak self] in
            self?.topVM?.clearAllFilters()
        }

        dotChipScrollView.setContentHuggingPriority(.required, for: .horizontal)
        dotChipScrollView.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )

        searchRow.addArrangedSubview(searchField)
        searchRow.addArrangedSubview(dotChipScrollView)
    }

    private func setupSettingBtn() {
        settingBtn.action = { [weak self] in self?.showSettingsMenu() }
        addSubview(settingBtn)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        if isSearching, result === searchRow {
            return nil
        }
        return result
    }

    // MARK: - Update Badge

    private func observeUpdateBadge() {
        withObservationTracking {
            settingBtn.showBadge = UpdateManager.shared.hasUpdate
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeUpdateBadge()
            }
        }
    }

    // MARK: - Settings Menu

    private func showSettingsMenu() {
        let builder = TopBarMenuBuilder(target: self, topVM: topVM)
        let menu = builder.buildSettingsMenu()
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: settingBtn)
        }
    }

    // MARK: - Layout

    private func layoutRows() {
        settingBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Const.space16)
            make.centerY.equalToSuperview()
        }

        defaultRow.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(100)
            make.trailing.lessThanOrEqualTo(settingBtn.snp.leading).offset(
                -Const.space12
            )
            make.top.equalToSuperview().offset(Const.space12)
        }

        searchRow.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(5)
            make.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(Const.space10)
        }
    }

    private func updateSearchFieldWidth() {
        guard let screenWidth = window?.frame.width, screenWidth > 0 else { return }

        let width = min(
            max(
                screenWidth * Const.searchFieldScreenWidthRatio,
                Const.searchFieldMinWidth
            ),
            Const.searchFieldMaxWidth
        )
        guard width != searchFieldWidth else { return }

        searchFieldWidth = width
        searchFieldWidthConstraint?.update(offset: width)
    }

    // MARK: - 模式切换

    private func activateSearch() {
        guard !isSearching else { return }
        updateSearchFieldWidth()
        isSearching = true
        applyMode()
        filterPopover?.prepare()
        loadAppSuggestionsIfNeeded()
        window?.makeFirstResponder(searchField)
        onFocusRegionChange?(.search)
    }

    func activateSearch(with character: String) {
        activateSearch()
        searchField.appendText(character)
    }

    func deactivateSearch() {
        guard isSearching else { return }
        isSearching = false
        searchField.hideSuggestions()
        searchField.clearAllContent()
        topVM?.clearInput()
        applyMode()
    }

    private func applyMode() {
        defaultRow.isHidden = isSearching
        searchRow.isHidden = !isSearching
    }

}
