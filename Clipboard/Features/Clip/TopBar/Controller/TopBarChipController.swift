//
//  TopBarChipController.swift
//  Clipboard
//
//  Created by crown on 2026/4/27.
//

import AppKit

final class TopBarChipController {
    // MARK: - Dependencies

    private weak var topVM: TopBarViewModel?
    private weak var chipScrollView: ChipScrollView?
    private weak var dotChipScrollView: ChipScrollView?

    // MARK: - Callbacks

    var onReloadNeeded: (() -> Void)?
    var onFocusRegionChange: ((FocusRegion) -> Void)?
    var onDeactivateSearch: (() -> Void)?

    // MARK: - State

    private(set) var isEditingChipFirstResponder = false

    // MARK: - Init

    init(
        topVM: TopBarViewModel?,
        chipScrollView: ChipScrollView,
        dotChipScrollView: ChipScrollView
    ) {
        self.topVM = topVM
        self.chipScrollView = chipScrollView
        self.dotChipScrollView = dotChipScrollView
    }

    func updateViewModel(_ topVM: TopBarViewModel) {
        self.topVM = topVM
    }

    // MARK: - Chip Reload

    func reloadChips() {
        guard let topVM else { return }

        let chips = topVM.chips()
        let currentId = topVM.getSelectChipId()

        chipScrollView?.reload(
            chips: chips,
            selectedId: currentId,
            dotMode: false,
            makeConfig: makeChipButtonConfig
        )
        chipScrollView?.onSelectionChanged = { [weak self] id in
            self?.handleChipSelection(id: id)
        }

        dotChipScrollView?.reload(
            chips: chips,
            selectedId: currentId,
            dotMode: true,
            makeConfig: makeChipButtonConfig
        )
        dotChipScrollView?.onSelectionChanged = { [weak self] id in
            self?.handleChipSelection(id: id)
        }

        if topVM.editingNewChip {
            appendNewChipPlaceholder()
        }
    }

    func updateChipSelection() {
        guard let topVM else { return }
        let currentId = topVM.getSelectChipId()
        chipScrollView?.selectedChipId = currentId
        dotChipScrollView?.selectedChipId = currentId
    }

    // MARK: - New Chip Creation

    func startCreatingChip() {
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

        chipScrollView?.appendNewChipButton(config: config)
    }

    private func refreshNewChipPlaceholder() {
        guard let topVM, topVM.editingNewChip else { return }
        chipScrollView?.removeNewChipButton()
        appendNewChipPlaceholder()
    }

    private func commitNewChip() {
        guard let topVM, topVM.editingNewChip else { return }
        topVM.editingNewChip = false
        isEditingChipFirstResponder = false
        topVM.commitNewChipOrCancel(commitIfNonEmpty: true)
        onReloadNeeded?()
        onFocusRegionChange?(.collection)
    }

    private func cancelNewChip() {
        guard let topVM, topVM.editingNewChip else { return }
        topVM.editingNewChip = false
        isEditingChipFirstResponder = false
        topVM.commitNewChipOrCancel(commitIfNonEmpty: false)
        onReloadNeeded?()
        onFocusRegionChange?(.collection)
    }

    func handleChipSelection(id: Int) {
        if let topVM {
            if topVM.editingNewChip {
                commitNewChip()
            } else if let editingId = topVM.editingChipId {
                commitChipEditing(for: editingId)
            }
        }
        onDeactivateSearch?()
        topVM?.setSelectChipId(chip: id)
        chipScrollView?.selectedChipId = id
        dotChipScrollView?.selectedChipId = id
        onReloadNeeded?()
        onFocusRegionChange?(.collection)
    }

    // MARK: - Chip Editing

    private func startEditingChip(_ chip: CategoryChip) {
        guard !chip.isSystem else { return }
        isEditingChipFirstResponder = false
        topVM?.startEditingChip(chip)
        onReloadNeeded?()
    }

    func commitChipEditing(for chipId: Int) {
        guard topVM?.editingChipId == chipId else { return }
        isEditingChipFirstResponder = false
        topVM?.commitEditingChip()
        onReloadNeeded?()
    }

    func cancelChipEditing(for chipId: Int) {
        guard topVM?.editingChipId == chipId else { return }
        isEditingChipFirstResponder = false
        topVM?.cancelEditingChip()
        onReloadNeeded?()
    }

    private func updateChipColor(_ chip: CategoryChip, colorIndex: Int) {
        topVM?.updateChip(chip, colorIndex: colorIndex)
        onReloadNeeded?()
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

    // MARK: - Chip Deletion

    private func confirmDeleteChip(_ chip: CategoryChip) {
        guard !chip.isSystem else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let count = await PasteDataStore.main.getCountByGroup(groupId: chip.id)
            if count == 0 {
                topVM?.removeChip(chip)
                onReloadNeeded?()
                return
            }

            let alert = NSAlert()
            alert.messageText = String(localized: .deleteChipTitle(chip.name))
            alert.informativeText = String(localized: .deleteChipMessage(chip.name))
            alert.alertStyle = .warning
            alert.addButton(withTitle: String(localized: .commonConfirm))
            alert.addButton(withTitle: String(localized: .commonCancel))

            AppEnvironment.shared.suppressResignKey = true
            let response = alert.runModal()
            AppEnvironment.shared.suppressResignKey = false

            guard response == .alertFirstButtonReturn else { return }
            topVM?.removeChip(chip)
            onReloadNeeded?()
        }
    }

    // MARK: - Drag & Drop

    private func handleCardDroppedOnChip(model: PasteboardModel, chip: CategoryChip) -> Bool {
        topVM?.assignModelToChip(model: model, chipId: chip.id) ?? false
    }

    // MARK: - Config Builder

    func makeChipButtonConfig(
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
}
