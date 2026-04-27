//
//  TopBarView.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import Combine
import SnapKit
import Sparkle

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

    private lazy var filterPopover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        return popover
    }()

    private lazy var filterPopoverVC: FilterPopoverViewController? = {
        guard let topVM else { return nil }
        return FilterPopoverViewController(viewModel: topVM)
    }()

    // MARK: - Callbacks

    var onFocusRegionChange: ((FocusRegion) -> Void)?

    // MARK: - State

    private(set) var isSearching = false
    private var topVM: TopBarViewModel?
    private(set) var isEditingChipFirstResponder = false
    private var isShowingPopover = false
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

    func configure(topVM: TopBarViewModel) {
        self.topVM = topVM
        reloadChips()
        setupTokenSync()
    }

    var isEditingChip: Bool {
        topVM?.isEditingChip ?? false
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
        addChipBtn.action = { [weak self] in self?.startCreatingChip() }

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

            if isShowingPopover {
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

    // MARK: - Settings Menu

    private static let appName: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Clipboard"

    private func setMenuItemImage(_ item: NSMenuItem, symbolName: String) {
        if #available(macOS 26.0, *) {
            item.image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: nil
            )
        }
    }

    private func showSettingsMenu() {
        let menu = NSMenu()
        let updateManager = UpdateManager.shared

        if updateManager.hasUpdate {
            let newVersionItem = NSMenuItem(
                title: String(
                    localized: .updateAvailable(
                        updateManager.availableVersion ?? ""
                    )
                ),
                action: #selector(checkForUpdatesAction),
                keyEquivalent: ""
            )
            newVersionItem.target = self
            if #available(macOS 26.0, *),
               let image = NSImage(
                   systemSymbolName: "arrow.up.circle.dotted",
                   accessibilityDescription: nil
               )
            {
                let config = NSImage.SymbolConfiguration(
                    pointSize: 16.0,
                    weight: .semibold
                )
                image.isTemplate = true
                newVersionItem.image = image.withSymbolConfiguration(config)
            }
            menu.addItem(newVersionItem)
            menu.addItem(.separator())
        } else {
            AppDelegate.shared?.updaterController.updater.checkForUpdatesInBackground()
        }

        let aboutItem = NSMenuItem(
            title: String(localized: .aboutApp(Self.appName)),
            action: #selector(openAboutAction),
            keyEquivalent: ""
        )
        aboutItem.target = self
        setMenuItemImage(aboutItem, symbolName: "info.circle")
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let newTextItem = NSMenuItem(
            title: String(localized: .newText),
            action: #selector(openNewTextItemAction),
            keyEquivalent: "t"
        )
        newTextItem.keyEquivalentModifierMask = .command
        newTextItem.target = self
        setMenuItemImage(newTextItem, symbolName: "square.and.pencil")
        menu.addItem(newTextItem)

        let settingsItem = NSMenuItem(
            title: String(localized: .settings),
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        setMenuItemImage(settingsItem, symbolName: "gearshape")
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let updateItem = NSMenuItem(
            title: String(localized: .checkUpdates),
            action: #selector(checkForUpdatesAction),
            keyEquivalent: ""
        )
        updateItem.target = self
        setMenuItemImage(updateItem, symbolName: "arrow.clockwise")
        menu.addItem(updateItem)

        let helpItem = NSMenuItem(
            title: String(localized: .menuHelp),
            action: #selector(invokeHelpAction),
            keyEquivalent: ""
        )
        helpItem.target = self
        setMenuItemImage(helpItem, symbolName: "questionmark.circle")
        menu.addItem(helpItem)

        menu.addItem(.separator())

        let pauseItem = NSMenuItem(
            title: topVM?.pauseMenuTitle ?? String(localized: .pause),
            action: nil,
            keyEquivalent: ""
        )
        setMenuItemImage(pauseItem, symbolName: "pause.circle")
        pauseItem.submenu = makePauseSubmenu()
        menu.addItem(pauseItem)

        let quitItem = NSMenuItem(
            title: String(localized: .quit),
            action: #selector(NSApplication.shared.terminate),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: settingBtn)
        }
    }

    private func makePauseSubmenu() -> NSMenu {
        let submenu = NSMenu()
        let isPaused = PasteBoard.main.isPaused

        if isPaused {
            let resumeItem = NSMenuItem(
                title: String(localized: .resume),
                action: #selector(resumePasteboardAction),
                keyEquivalent: ""
            )
            resumeItem.target = self
            setMenuItemImage(resumeItem, symbolName: "play.circle")
            submenu.addItem(resumeItem)
            submenu.addItem(.separator())
        } else {
            let pauseIndefiniteItem = NSMenuItem(
                title: String(localized: .pause),
                action: #selector(pauseIndefinitelyAction),
                keyEquivalent: ""
            )
            pauseIndefiniteItem.target = self
            setMenuItemImage(pauseIndefiniteItem, symbolName: "pause.circle")
            submenu.addItem(pauseIndefiniteItem)
            submenu.addItem(.separator())
        }

        let durations: [(String, String, Selector)] = [
            (
                String(localized: .pauseFifteen), "15.circle",
                #selector(pause15MinutesAction)
            ),
            (
                String(localized: .pauseThirty), "30.circle",
                #selector(pause30MinutesAction)
            ),
            (
                String(localized: .pauseOneHour), "1.circle",
                #selector(pause1HourAction)
            ),
            (
                String(localized: .pauseThreeHours), "3.circle",
                #selector(pause3HoursAction)
            ),
            (
                String(localized: .pauseEightHours), "8.circle",
                #selector(pause8HoursAction)
            ),
        ]

        for (title, symbol, selector) in durations {
            let item = NSMenuItem(
                title: title,
                action: selector,
                keyEquivalent: ""
            )
            item.target = self
            setMenuItemImage(item, symbolName: symbol)
            submenu.addItem(item)
        }

        return submenu
    }

    // MARK: - Menu Actions

    @objc private func openSettingsAction() {
        SettingWindowController.shared.toggleWindow()
    }

    @objc private func checkForUpdatesAction() {
        AppDelegate.shared?.updaterController.checkForUpdates(nil)
    }

    @objc private func invokeHelpAction() {
        if let url = URL(
            string:
            "https://github.com/Ineffable919/clipboard/blob/master/README.md"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openNewTextItemAction() {
        EditWindowController.shared.openNewWindow()
    }

    @objc private func openAboutAction() {
        SettingWindowController.shared.toggleWindow(page: .about)
    }

    @objc private func resumePasteboardAction() {
        topVM?.resume()
    }

    @objc private func pauseIndefinitelyAction() {
        topVM?.pauseIndefinitely()
    }

    @objc private func pause15MinutesAction() {
        topVM?.pause(for: 15)
    }

    @objc private func pause30MinutesAction() {
        topVM?.pause(for: 30)
    }

    @objc private func pause1HourAction() {
        topVM?.pause(for: 60)
    }

    @objc private func pause3HoursAction() {
        topVM?.pause(for: 180)
    }

    @objc private func pause8HoursAction() {
        topVM?.pause(for: 480)
    }

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

    // MARK: - Chip Reload

    func reloadChips() {
        guard let topVM else { return }

        let chips = topVM.chips()
        let currentId = topVM.getSelectChipId()

        chipScrollView.reload(
            chips: chips,
            selectedId: currentId,
            dotMode: false,
            makeConfig: makeChipButtonConfig
        )
        chipScrollView.onSelectionChanged = { [weak self] id in
            self?.handleChipSelection(id: id)
        }

        dotChipScrollView.reload(
            chips: chips,
            selectedId: currentId,
            dotMode: true,
            makeConfig: makeChipButtonConfig
        )
        dotChipScrollView.onSelectionChanged = { [weak self] id in
            self?.handleChipSelection(id: id)
        }

        if topVM.editingNewChip {
            appendNewChipPlaceholder()
        }
    }

    func updateChipSelection() {
        guard let topVM else { return }
        let currentId = topVM.getSelectChipId()
        chipScrollView.selectedChipId = currentId
        dotChipScrollView.selectedChipId = currentId
    }

    // MARK: - New Chip Creation

    private func startCreatingChip() {
        guard let topVM else { return }
        if topVM.editingNewChip {
            commitNewChip()
        }
        if let editingId = topVM.editingChipId {
            commitChipEditing(for: editingId)
        }
        topVM.editingNewChip = true
        topVM.newChipName = String(localized: .untitled)
        appendNewChipPlaceholder()
    }

    private func appendNewChipPlaceholder() {
        guard let topVM else { return }

        let placeholder = CategoryChip(
            id: Int.min,
            name: topVM.newChipName,
            colorIndex: topVM.newChipColorIndex,
            isSystem: false
        )

        let config = ChipButton.Config(
            chip: placeholder,
            isSelected: true,
            dotMode: false,
            isEditing: true,
            editingName: topVM.newChipName,
            editingColorIndex: topVM.newChipColorIndex,
            action: {},
            onEdit: nil,
            onDelete: nil,
            onColorChange: { [weak self] colorIndex in
                self?.topVM?.newChipColorIndex = colorIndex
                self?.refreshNewChipPlaceholder()
            },
            onEditingNameChange: { [weak self] text in
                self?.topVM?.newChipName = text
            },
            onEditingSubmit: { [weak self] in
                self?.commitNewChip()
            },
            onEditingCancel: { [weak self] in
                self?.cancelNewChip()
            },
            onEditingFocusChange: { [weak self] focused in
                self?.isEditingChipFirstResponder = focused
                self?.onFocusRegionChange?(focused ? .chipEditing : .collection)
            }
        )

        chipScrollView.appendNewChipButton(config: config)
    }

    private func refreshNewChipPlaceholder() {
        guard let topVM, topVM.editingNewChip else { return }
        chipScrollView.removeNewChipButton()
        appendNewChipPlaceholder()
    }

    private func commitNewChip() {
        guard let topVM, topVM.editingNewChip else { return }
        topVM.editingNewChip = false
        isEditingChipFirstResponder = false
        topVM.commitNewChipOrCancel(commitIfNonEmpty: true)
        reloadChips()
        onFocusRegionChange?(.collection)
    }

    private func cancelNewChip() {
        guard let topVM, topVM.editingNewChip else { return }
        topVM.editingNewChip = false
        isEditingChipFirstResponder = false
        topVM.commitNewChipOrCancel(commitIfNonEmpty: false)
        reloadChips()
        onFocusRegionChange?(.collection)
    }

    private func handleChipSelection(id: Int) {
        if let topVM {
            if topVM.editingNewChip {
                commitNewChip()
            } else if let editingId = topVM.editingChipId {
                commitChipEditing(for: editingId)
            }
        }
        deactivateSearch()
        topVM?.setSelectChipId(chip: id)
        chipScrollView.selectedChipId = id
        dotChipScrollView.selectedChipId = id
        reloadChips()
        onFocusRegionChange?(.collection)
    }

    // MARK: - 模式切换

    private func activateSearch() {
        guard !isSearching else { return }
        isSearching = true
        applyMode()
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
        searchField.clearAllContent()
        topVM?.clearInput()
        applyMode()
    }

    private func applyMode() {
        defaultRow.isHidden = isSearching
        searchRow.isHidden = !isSearching
    }

    private func makeChipButtonConfig(
        chip: CategoryChip,
        isSelected: Bool,
        dotMode: Bool
    ) -> ChipButton.Config {
        let isEditing = !dotMode && topVM?.editingChipId == chip.id

        return .init(
            chip: chip,
            isSelected: isSelected,
            dotMode: dotMode,
            isEditing: isEditing,
            editingName: isEditing
                ? (topVM?.editingChipName ?? chip.name) : chip.name,
            editingColorIndex: isEditing
                ? (topVM?.editingChipColorIndex ?? chip.colorIndex)
                : chip.colorIndex,
            action: { [weak self] in
                self?.handleChipSelection(id: chip.id)
            },
            onEdit: { [weak self] in
                self?.startEditingChip(chip)
            },
            onDelete: { [weak self] in
                self?.confirmDeleteChip(chip)
            },
            onColorChange: { [weak self] colorIndex in
                self?.updateChipColor(chip, colorIndex: colorIndex)
            },
            onEditingNameChange: { [weak self] text in
                self?.topVM?.editingChipName = text
            },
            onEditingSubmit: { [weak self] in
                self?.commitChipEditing(for: chip.id)
            },
            onEditingCancel: { [weak self] in
                self?.cancelChipEditing(for: chip.id)
            },
            onEditingFocusChange: { [weak self] focused in
                self?.handleEditingChipFocusChange(
                    for: chip.id,
                    focused: focused
                )
            },
            onDrop: { [weak self] model in
                self?.handleCardDroppedOnChip(model: model, chip: chip) ?? false
            }
        )
    }

    private func startEditingChip(_ chip: CategoryChip) {
        guard !chip.isSystem else { return }
        isEditingChipFirstResponder = false
        topVM?.startEditingChip(chip)
        reloadChips()
    }

    private func commitChipEditing(for chipId: Int) {
        guard topVM?.editingChipId == chipId else { return }
        isEditingChipFirstResponder = false
        topVM?.commitEditingChip()
        reloadChips()
    }

    private func cancelChipEditing(for chipId: Int) {
        guard topVM?.editingChipId == chipId else { return }
        isEditingChipFirstResponder = false
        topVM?.cancelEditingChip()
        reloadChips()
    }

    private func updateChipColor(_ chip: CategoryChip, colorIndex: Int) {
        topVM?.updateChip(chip, colorIndex: colorIndex)
        reloadChips()
    }

    private func handleEditingChipFocusChange(for chipId: Int, focused: Bool) {
        guard topVM?.editingChipId == chipId else { return }
        isEditingChipFirstResponder = focused
        onFocusRegionChange?(focused ? .chipEditing : .collection)
    }

    func commitKeyboardEditing() {
        if let topVM, topVM.editingNewChip {
            commitNewChip()
        } else if let chipId = topVM?.editingChipId {
            commitChipEditing(for: chipId)
        }
    }

    func cancelKeyboardEditing() {
        if let topVM, topVM.editingNewChip {
            cancelNewChip()
        } else if let chipId = topVM?.editingChipId {
            cancelChipEditing(for: chipId)
        }
    }

    private func confirmDeleteChip(_ chip: CategoryChip) {
        guard !chip.isSystem else { return }

        let alert = NSAlert()
        alert.messageText = String(localized: .deleteChipTitle(chip.name))
        alert.informativeText = String(localized: .deleteChipMessage(chip.name))
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: .commonConfirm))
        alert.addButton(withTitle: String(localized: .commonCancel))

        let handleResponse: (NSApplication.ModalResponse) -> Void = {
            [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.topVM?.removeChip(chip)
            self?.reloadChips()
        }
        defer {
            AppEnvironment.shared.suppressResignKey = false
        }
        AppEnvironment.shared.suppressResignKey = true
        let response = alert.runModal()
        handleResponse(response)
    }

    // MARK: - Drag & Drop

    private func handleCardDroppedOnChip(model: PasteboardModel, chip: CategoryChip) -> Bool {
        topVM?.assignModelToChip(model: model, chipId: chip.id) ?? false
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
        searchField.clearTokensOnly()
        searchField.insertTokens(topVM.tags)
    }

    private func handleTokenDeletedFromSearchField(_ tag: InputTag) {
        topVM?.removeTag(tag)
    }

    private func togglePopover() {
        guard let filterPopoverVC else { return }
        if filterPopover.contentViewController == nil {
            filterPopover.contentViewController = filterPopoverVC
        }

        if filterPopover.isShown {
            filterPopover.close()
            isShowingPopover = false
            return
        }

        isShowingPopover = true

        filterPopover.show(
            relativeTo: searchField.filterButton.bounds,
            of: searchField.filterButton,
            preferredEdge: .maxY
        )
        Task { @MainActor in
            onFocusRegionChange?(.filter)
            filterPopoverVC.view.window?.makeFirstResponder(filterPopoverVC.view)
        }
    }
}

// MARK: - NSPopoverDelegate

extension TopBarView: NSPopoverDelegate {
    func popoverDidClose(_: Notification) {
        isShowingPopover = false

        guard isSearching, let topVM else { return }

        Task { @MainActor [weak self] in
            guard let self, isSearching, !topVM.hasInput else { return }

            if !searchField.isFirstResponder {
                deactivateSearch()
                onFocusRegionChange?(.collection)
            }
        }
    }
}
