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
    let searchField = SearchField()
    private let dotChipScrollView = ChipScrollView()

    // MARK: - Popover

    private var filterPopover: FilterPopover?

    // MARK: - Callbacks

    var onFocusRegionChange: ((FocusRegion) -> Void)?

    // MARK: - State

    private(set) var isSearching = false
    private(set) var topVM: TopBarViewModel?
    private var cancellables = Set<AnyCancellable>()
    private var shouldSkipNextTokenSync = false

    private lazy var chipController = TopBarChipController(
        topVM: topVM,
        chipScrollView: chipScrollView,
        dotChipScrollView: dotChipScrollView
    )

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

    func configure(topVM: TopBarViewModel) {
        self.topVM = topVM

        filterPopover = FilterPopover(viewModel: topVM)
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

    var isEditingChip: Bool {
        topVM?.isEditingChip ?? false
    }

    func reloadChips() {
        chipController.reloadChips()
    }

    func updateChipSelection() {
        chipController.updateChipSelection()
    }

    func commitKeyboardEditing() {
        chipController.commitKeyboardEditing()
    }

    func cancelKeyboardEditing() {
        chipController.cancelKeyboardEditing()
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
            make.width.equalTo(Const.topBarWidth)
            make.height.equalTo(32)
        }

        searchField.onResignFirstResponder = { [weak self] in
            guard let self, let topVM else { return }

            if filterPopover?.isShowingPopover == true {
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

    // MARK: - 模式切换

    private func activateSearch() {
        guard !isSearching else { return }
        isSearching = true
        applyMode()
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

    // MARK: - Filter Popover

    private func setupTokenSync() {
        guard let topVM else { return }

        topVM.filterDidChange
            .sink { [weak self] in
                self?.syncTokensToSearchField()
            }
            .store(in: &cancellables)

        topVM.clearQueryRequested
            .sink { [weak self] in
                self?.searchField.clearTextSilently()
            }
            .store(in: &cancellables)
    }

    private func syncTokensToSearchField() {
        guard let topVM else { return }
        if shouldSkipNextTokenSync {
            shouldSkipNextTokenSync = false
            updateChipSelection()
            return
        }

        searchField.clearTokensOnly()
        searchField.insertTokens(topVM.tags)
        updateChipSelection()
    }

    private func handleTokenDeletedFromSearchField(_ tag: InputTag) {
        shouldSkipNextTokenSync = true
        topVM?.removeTag(tag)
    }

    private func togglePopover() {
        guard let filterPopover else { return }

        filterPopover.toggle(
            relativeTo: searchField.filterButton.bounds,
            of: searchField.filterButton
        )

        if filterPopover.isShowingPopover {
            onFocusRegionChange?(.filter)
        }
    }

    private func handlePopoverDidClose() {
        guard isSearching, let topVM else { return }

        Task { @MainActor [weak self] in
            guard let self, isSearching, !topVM.hasInput else { return }

            if !searchField.isFirstResponder {
                deactivateSearch()
                onFocusRegionChange?(.collection)
            }
        }
    }

    // MARK: - Fuzzy Match

    private func fuzzyMatch(_ text: String, query: String) -> Bool {
        let text = text.lowercased()
        let query = query.lowercased()
        var queryIndex = query.startIndex

        for char in text {
            if queryIndex < query.endIndex, char == query[queryIndex] {
                query.formIndex(after: &queryIndex)
            }
        }

        return queryIndex == query.endIndex
    }

    // MARK: - Suggestion Data Source

    private func buildSuggestions(query: String) -> [SearchSuggestionItem] {
        guard !query.isEmpty else { return [] }

        var result: [SearchSuggestionItem] = []

        // 类型
        let allTypes: [PasteModelType] = [.color, .file, .image, .link, .string]
        for type in allTypes {
            guard topVM?.selectedTypes.contains(type) != true else { continue }
            let (icon, label) = type.iconAndLabel
            guard fuzzyMatch(label, query: query) else { continue }
            let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
            result.append(SearchSuggestionItem(
                title: label,
                icon: image,
                action: .toggleType(type)
            ))
        }

        // 日期
        for option in DateFilterOption.allCases {
            guard topVM?.selectedDateFilter != option else { continue }
            let label = option.displayName
            guard fuzzyMatch(label, query: query) else { continue }
            let image = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)
            result.append(SearchSuggestionItem(
                title: label,
                icon: image,
                action: .setDate(option)
            ))
        }

        // 标签（用户自定义分组）
        let userChips = CategoryChipStore.shared.chips.filter { !$0.isSystem }
        for chip in userChips {
            guard topVM?.selectedGroupId != chip.id else { continue }
            guard fuzzyMatch(chip.name, query: query) else { continue }
            let dotIcon = makeChipDotIcon(colorIndex: chip.colorIndex)
            result.append(SearchSuggestionItem(
                title: chip.name,
                icon: dotIcon,
                action: .setGroup(chip.id)
            ))
        }

        // 应用
        if let cachedApps = cachedAppSuggestions {
            for app in cachedApps {
                guard topVM?.selectedAppNames.contains(app.name) != true else { continue }
                guard fuzzyMatch(app.name, query: query) else { continue }
                result.append(SearchSuggestionItem(
                    title: app.name,
                    icon: app.icon,
                    action: .toggleApp(app.name, app.path)
                ))
            }
        }

        return result
    }

    private func handleSuggestionSelected(_ item: SearchSuggestionItem) {
        guard let topVM else { return }

        searchField.clearTextSilently()
        topVM.setQuery(text: "")

        switch item.action {
        case let .toggleType(type):
            topVM.toggleType(type)
        case let .toggleApp(name, path):
            topVM.toggleApp(name, appPath: path)
        case let .setDate(option):
            topVM.setDateFilter(option)
        case let .setGroup(id):
            topVM.setGroupFilter(id)
        }
    }

    // MARK: - App Suggestions Cache

    private struct AppSuggestionInfo {
        let name: String
        let path: String
        let icon: NSImage?
    }

    private static var _cachedAppSuggestions: [AppSuggestionInfo]?

    private var cachedAppSuggestions: [AppSuggestionInfo]? {
        get { Self._cachedAppSuggestions }
        set { Self._cachedAppSuggestions = newValue }
    }

    func loadAppSuggestionsIfNeeded() {
        guard cachedAppSuggestions == nil else { return }
        Task { @MainActor [weak self] in
            let appInfo = await PasteMetadataCache.shared.getAllAppInfo()
            var suggestions: [AppSuggestionInfo] = []
            for info in appInfo {
                let icon = await AppIconCache.shared.loadIcon(forPath: info.path)
                suggestions.append(AppSuggestionInfo(
                    name: info.name,
                    path: info.path,
                    icon: icon
                ))
            }
            self?.cachedAppSuggestions = suggestions
            if let self, !self.searchField.text.isEmpty {
                searchField.showSuggestions()
            }
        }
    }

    private func makeChipDotIcon(colorIndex: Int) -> NSImage {
        let canvasSize: CGFloat = 14
        let dotSize: CGFloat = 10
        let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
        image.lockFocus()
        let color = CategoryChip.nsColor(at: colorIndex)
        color.setFill()
        let origin = (canvasSize - dotSize) / 2
        NSBezierPath(ovalIn: NSRect(x: origin, y: origin, width: dotSize, height: dotSize)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
