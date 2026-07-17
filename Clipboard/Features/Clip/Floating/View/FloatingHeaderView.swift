//
//  FloatingHeaderView.swift
//  Clipboard
//
//  浮动窗口顶部：拖拽区 + Pin 按钮 + 搜索框 + 分类标签行
//

import AppKit
import Combine
import SnapKit
import Sparkle

final class FloatingHeaderView: NSView {
    // MARK: - Subviews

    private let dragHandle = FloatingDragHandle()
    private let pinButton = FloatingPinButton()
    let searchField = FloatingSearchField()
    private let settingsBtn = TopBarIconButton(symbolName: "ellipsis")
    private let chipScrollView = ChipScrollView()
    private let addChipBtn = TopBarIconButton(symbolName: "plus")

    // MARK: - State

    private var effectView: NSView = FloatingHeaderView.buildEffectView()
    private var lastBackgroundType: Int = PasteUserDefaults.backgroundType
    private weak var topVM: TopBarViewModel?
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

    var onSearchBecameFirstResponder: (() -> Void)?
    var onChipSelected: (() -> Void)?
    var onChipEditingFocusChange: ((Bool) -> Void)?

    func isExcludedFromFocusGesture(_ view: NSView) -> Bool {
        let isEditingChip = topVM?.isEditingChip == true || topVM?.editingNewChip == true
        return view === pinButton || view.isDescendant(of: pinButton) ||
            view === searchField || view.isDescendant(of: searchField) ||
            view === settingsBtn || view.isDescendant(of: settingsBtn) ||
            view === addChipBtn || view.isDescendant(of: addChipBtn) ||
            (isEditingChip && view.isDescendant(of: chipScrollView))
    }

    func configure(topVM: TopBarViewModel) {
        self.topVM = topVM
        reloadChips()
    }

    var isSearchFieldFirstResponder: Bool {
        window?.firstResponder === searchField
    }

    func reloadChips() {
        guard let topVM else { return }
        let chips = topVM.chips()
        let selectedId = topVM.getSelectChipId()

        chipScrollView.reload(
            chips: chips,
            selectedId: selectedId,
            dotMode: false,
            compact: true,
            makeConfig: { [weak self] chip, isSelected, dotMode in
                let isEditing = topVM.editingChipId == chip.id
                return .init(
                    chip: chip,
                    isSelected: isSelected,
                    dotMode: dotMode,
                    compact: true,
                    isEditing: isEditing,
                    editingName: isEditing ? topVM.editingChipName : chip.name,
                    editingColorIndex: isEditing ? topVM.editingChipColorIndex : chip.colorIndex,
                    action: { [weak self] in
                        self?.chipScrollView.selectedChipId = chip.id
                        self?.chipScrollView.onSelectionChanged?(chip.id)
                    },
                    onEdit: { [weak self] in
                        topVM.startEditingChip(chip)
                        self?.reloadChips()
                    },
                    onDelete: { [weak self] in
                        self?.confirmDeleteChip(chip)
                    },
                    onColorChange: { [weak self] colorIndex in
                        topVM.updateChip(chip, colorIndex: colorIndex)
                        self?.reloadChips()
                    },
                    onEditingNameChange: { text in
                        topVM.editingChipName = text
                    },
                    onEditingSubmit: { [weak self] in
                        topVM.commitEditingChip()
                        self?.reloadChips()
                    },
                    onEditingCancel: { [weak self] in
                        topVM.cancelEditingChip()
                        self?.reloadChips()
                    },
                    onEditingFocusChange: { [weak self] focused in
                        self?.onChipEditingFocusChange?(focused)
                    },
                    onDrop: { [weak self] model in
                        self?.topVM?.assignModelToChip(model: model, chipId: chip.id) ?? false
                    }
                )
            }
        )
        chipScrollView.onSelectionChanged = { [weak self] id in
            self?.topVM?.setSelectChipId(chip: id)
            self?.chipScrollView.scrollToChip(id: id)
            self?.onChipSelected?()
        }

        if topVM.editingNewChip {
            appendNewChipPlaceholder()
        }
    }

    // MARK: - New Chip Creation

    private func startCreatingChip() {
        startCreatingChip(pinModel: nil)
    }

    func startCreatingChip(pinModel: PasteboardModel?) {
        guard let topVM else { return }
        if topVM.editingNewChip {
            commitNewChip()
        }
        if topVM.editingChipId != nil {
            topVM.commitEditingChip()
        }
        topVM.editingNewChip = true
        topVM.newChipName = String(localized: .untitled)
        topVM.pendingPinModel = pinModel
        reloadChips()
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
            compact: true,
            isEditing: true,
            editingName: topVM.newChipName,
            editingColorIndex: topVM.newChipColorIndex,
            action: {},
            onColorChange: { [weak self] colorIndex in
                self?.topVM?.newChipColorIndex = colorIndex
                self?.refreshNewChipPlaceholder()
            },
            onEditingNameChange: { [weak self] text in
                self?.topVM?.newChipName = text
            },
            onEditingSubmit: { [weak self] in self?.commitNewChip() },
            onEditingCancel: { [weak self] in self?.cancelNewChip() },
            onEditingFocusChange: { [weak self] focused in
                self?.onChipEditingFocusChange?(focused)
            }
        )
        chipScrollView.appendNewChipButton(config: config)
        chipScrollView.scrollToEnd()
    }

    private func refreshNewChipPlaceholder() {
        guard let topVM, topVM.editingNewChip else { return }
        chipScrollView.removeNewChipButton()
        appendNewChipPlaceholder()
    }

    private func commitNewChip() {
        endNewChip(commit: true)
    }

    private func cancelNewChip() {
        endNewChip(commit: false)
    }

    private func endNewChip(commit: Bool) {
        guard let topVM, topVM.editingNewChip else { return }
        topVM.editingNewChip = false
        topVM.commitNewChipOrCancel(commitIfNonEmpty: commit)
        reloadChips()
        if commit {
            onChipSelected?()
        }
    }

    private func confirmDeleteChip(_ chip: CategoryChip) {
        guard !chip.isSystem else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let count = await PasteDataStore.main.getCountByGroup(groupId: chip.id)
            if count == 0 {
                topVM?.removeChip(chip)
                reloadChips()
                return
            }

            guard NSAlert.runConfirm(
                title: String(localized: .deleteChipTitle(chip.name)),
                message: String(localized: .deleteChipMessage(chip.name))
            ) else { return }
            topVM?.removeChip(chip)
            reloadChips()
        }
    }

    func commitKeyboardEditing() {
        guard let topVM else { return }
        if topVM.editingNewChip {
            commitNewChip()
        } else if topVM.editingChipId != nil {
            topVM.commitEditingChip()
            reloadChips()
        }
    }

    func cancelKeyboardEditing() {
        guard let topVM else { return }
        if topVM.editingNewChip {
            cancelNewChip()
        } else if topVM.editingChipId != nil {
            topVM.cancelEditingChip()
            reloadChips()
        }
    }

    func updateChipSelection() {
        guard let topVM else { return }
        let currentId = topVM.getSelectChipId()
        chipScrollView.selectedChipId = currentId
    }

    func clearSearch() {
        searchField.stringValue = ""
        topVM?.setQuery(text: "")
    }

    func activateSearch(with text: String?) {
        window?.makeFirstResponder(searchField)
        if let text, !text.isEmpty {
            searchField.stringValue = text
            topVM?.setQuery(text: text)
            searchField.currentEditor()?.selectedRange = NSRange(location: text.utf16.count, length: 0)
        }
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true

        addSubview(effectView)
        effectView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(Const.windowRadis)
        }

        addSubview(dragHandle)
        addSubview(pinButton)
        addSubview(searchField)
        addSubview(settingsBtn)
        chipScrollView.scrollMode = true
        addSubview(chipScrollView)
        addSubview(addChipBtn)

        // 拖拽区
        dragHandle.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(16)
        }

        // Pin
        pinButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Const.space12)
            make.top.equalTo(dragHandle.snp.bottom).offset(Const.space4)
        }

        // 设置
        settingsBtn.action = { [weak self] in self?.showSettingsMenu() }
        settingsBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Const.space12)
            make.centerY.equalTo(pinButton)
        }

        // 搜索框
        (searchField.cell as? NSSearchFieldCell)?.cancelButtonCell?.target = self
        (searchField.cell as? NSSearchFieldCell)?.cancelButtonCell?.action = #selector(clearSearchField)
        searchField.onBecomeFirstResponder = { [weak self] in
            self?.onSearchBecameFirstResponder?()
        }

        searchField.snp.makeConstraints { make in
            make.leading.equalTo(pinButton.snp.trailing).offset(Const.space12)
            make.trailing.equalTo(settingsBtn.snp.leading).offset(-Const.space8)
            make.top.equalTo(dragHandle.snp.bottom).offset(Const.space8)
            make.centerY.equalTo(pinButton)
        }

        addChipBtn.action = { [weak self] in
            self?.startCreatingChip()
        }

        chipScrollView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Const.space8)
            make.trailing.equalTo(addChipBtn.snp.leading).offset(-Const.space4)
            make.top.equalTo(searchField.snp.bottom).offset(Const.space8)
            make.bottom.equalToSuperview()
        }

        addChipBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Const.space12)
            make.centerY.equalTo(chipScrollView)
        }

        UserDefaults.standard.publisher(for: \.backgroundType)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleBackgroundSettingsChange() }
            .store(in: &cancellables)

        observeUpdateBadge()
    }

    private func observeUpdateBadge() {
        withObservationTracking {
            settingsBtn.showBadge = UpdateManager.shared.hasUpdate
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeUpdateBadge()
            }
        }
    }

    // MARK: - Background

    private static func buildEffectView() -> NSView {
        let topCorners: CACornerMask = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        if #available(macOS 26.0, *) {
            let bgType = BackgroundType(rawValue: PasteUserDefaults.backgroundType) ?? .liquid
            if bgType == .liquid {
                let v = NSGlassEffectView()
                v.cornerRadius = Const.windowRadis
                v.wantsLayer = true
                v.layer?.maskedCorners = topCorners
                return v
            }
        }
        let ve = NSVisualEffectView()
        ve.wantsLayer = true
        ve.state = .active
        ve.blendingMode = .withinWindow
        ve.material = .popover
        ve.layer?.cornerRadius = Const.windowRadis
        ve.layer?.maskedCorners = topCorners
        ve.layer?.masksToBounds = true
        return ve
    }

    private func handleBackgroundSettingsChange() {
        let currentBgType = PasteUserDefaults.backgroundType
        guard currentBgType != lastBackgroundType else { return }
        lastBackgroundType = currentBgType
        rebuildEffectView()
    }

    private func rebuildEffectView() {
        effectView.removeFromSuperview()
        effectView = Self.buildEffectView()
        addSubview(effectView, positioned: .below, relativeTo: dragHandle)
        effectView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(Const.windowRadis)
        }
        layoutSubtreeIfNeeded()
    }

    // MARK: - Settings Menu

    private func showSettingsMenu() {
        let builder = TopBarMenuBuilder(target: self, topVM: topVM)
        let menu = builder.buildSettingsMenu()
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: settingsBtn)
        }
    }

    // MARK: - Actions

    @objc private func clearSearchField() {
        searchField.stringValue = ""
        topVM?.setQuery(text: "")
    }
}

// MARK: - TopBarMenuActions

extension FloatingHeaderView: TopBarMenuActions {
    func openSettingsAction() {
        SettingWindowController.shared.toggleWindow()
    }

    func checkForUpdatesAction() {
        AppDelegate.shared?.updaterController.checkForUpdates(nil)
    }

    func invokeHelpAction() {
        if let url = URL(string: "https://github.com/Ineffable919/clipboard/blob/master/README.md") {
            NSWorkspace.shared.open(url)
        }
    }

    func openNewTextItemAction() {
        EditWindowController.shared.openNewWindow()
    }

    func openAboutAction() {
        SettingWindowController.shared.toggleWindow(page: .about)
    }

    func resumePasteboardAction() {
        topVM?.resume()
    }

    func pauseIndefinitelyAction() {
        topVM?.pauseIndefinitely()
    }

    func pause15MinutesAction() {
        topVM?.pause(for: 15)
    }

    func pause30MinutesAction() {
        topVM?.pause(for: 30)
    }

    func pause1HourAction() {
        topVM?.pause(for: 60)
    }

    func pause3HoursAction() {
        topVM?.pause(for: 180)
    }

    func pause8HoursAction() {
        topVM?.pause(for: 480)
    }
}

// MARK: - FloatingDragHandle

private final class FloatingDragHandle: NSView {
    private let pill = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 2
        addSubview(pill)
        pill.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(36)
            make.height.equalTo(4)
        }
        updateColor()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColor()
    }

    private func updateColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            pill.layer?.backgroundColor = NSColor.secondaryLabelColor
                .withAlphaComponent(0.3).cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - FloatingSearchField

final class FloatingSearchField: NSSearchField {
    @Published private(set) var text: String = ""
    var onBecomeFirstResponder: (() -> Void)?

    override var stringValue: String {
        didSet {
            if stringValue != text {
                text = stringValue
            }
        }
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        text = stringValue
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        placeholderString = String(localized: .search)
        controlSize = .large
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            onBecomeFirstResponder?()
        }
        return result
    }
}

// MARK: - FloatingPinButton

final class FloatingPinButton: NSButton {
    private(set) var isPinned = false {
        didSet { updateAppearance() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private func setup() {
        isBordered = false
        imageScaling = .scaleProportionallyUpOrDown
        target = self
        action = #selector(toggle)
        toolTip = String(localized: .pin)
        updateAppearance()
    }

    @objc private func toggle() {
        isPinned.toggle()
        ClipFloatingWindowController.shared.isPinned = isPinned
        toolTip = String(localized: isPinned ? .unpin : .pin)
    }

    private func updateAppearance() {
        let symbolName = isPinned ? "pin.fill" : "pin"
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        contentTintColor = isPinned ? .controlAccentColor : .secondaryLabelColor
    }
}
