//
//  FloatingHeaderView.swift
//  Clipboard
//
//  浮动窗口顶部：拖拽区 + Pin 按钮 + 搜索框 + 分类标签行
//

import AppKit
import Combine
import SnapKit
import SwiftUI
import Sparkle

final class FloatingHeaderView: NSView {
    // MARK: - Subviews

    let backgroundView = NSView()

    let dragHandle = FloatingDragHandle()
    let pinButton = FloatingPinButton()
    let searchField = FloatingSearchField()
    let settingsBtn = TopBarIconButton(symbolName: "ellipsis")
    let chipScrollView = ChipScrollView()
    let addChipBtn = TopBarIconButton(symbolName: "plus")

    // MARK: - State

    let effectView: NSView = FloatingHeaderView.buildEffectView()
    weak var topVM: TopBarViewModel?

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
        updateBackground()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Public API

    var onSearchBecameFirstResponder: (() -> Void)?
    var onChipSelected: (() -> Void)?
    var onChipEditingFocusChange: ((Bool) -> Void)?

    func setDisplayMode(_ mode: FloatingDisplayMode) {
        let isStandard = mode == .standard
        dragHandle.snp.updateConstraints { $0.height.equalTo(isStandard ? 16 : 12) }
        searchField.controlSize = isStandard ? .large : .regular
        searchField.snp.updateConstraints {
            $0.top.equalTo(dragHandle.snp.bottom).offset(isStandard ? Const.space8 : Const.space4)
        }
    }
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

    func setup() {
        wantsLayer = true
        layer?.masksToBounds = true

        setupBackground()

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
            make.centerY.equalTo(searchField)
            make.width.height.equalTo(28)
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
            make.leading.equalTo(pinButton.snp.trailing).offset(Const.space8)
            make.trailing.equalTo(settingsBtn.snp.leading).offset(-Const.space8)
            make.top.equalTo(dragHandle.snp.bottom).offset(Const.space8)
        }

        addChipBtn.action = { [weak self] in
            self?.startCreatingChip()
        }

        chipScrollView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Const.space12)
            make.trailing.equalTo(addChipBtn.snp.leading).offset(-Const.space4)
            make.top.equalTo(searchField.snp.bottom).offset(Const.space8)
            make.bottom.equalToSuperview()
        }

        addChipBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Const.space12)
            make.centerY.equalTo(chipScrollView)
        }

        observeUpdateBadge()
    }

    func observeUpdateBadge() {
        withObservationTracking {
            settingsBtn.showBadge = UpdateManager.shared.hasUpdate
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeUpdateBadge()
            }
        }
    }

    // MARK: - Background

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
    }

    func setupBackground() {
        addSubview(effectView)
        effectView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(Const.windowRadis)
        }

        guard #available(macOS 26.0, *) else { return }
        backgroundView.wantsLayer = true
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func updateBackground() {
        guard #available(macOS 26.0, *) else { return }
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        backgroundView.layer?.backgroundColor = NSColor(WelcomeStyle.background(for: isDark ? .dark : .light))
            .withAlphaComponent(0.35).cgColor
    }

    private static func buildEffectView() -> NSView {
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.cornerRadius = 0
            return glassView
        }
        let effect = NSVisualEffectView()
        effect.wantsLayer = true
        effect.state = .active
        effect.blendingMode = .withinWindow
        effect.material = .popover
        return effect
    }

    // MARK: - Settings Menu

    func showSettingsMenu() {
        let builder = TopBarMenuBuilder(target: self, topVM: topVM)
        let menu = builder.buildSettingsMenu()
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: settingsBtn)
        }
    }

    // MARK: - Actions

    @objc func clearSearchField() {
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
