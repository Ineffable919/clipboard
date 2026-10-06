import AppKit
import Combine
import SnapKit

extension FloatingHeaderView {
    func reloadChips() {
        guard let topVM else { return }
        let chips = topVM.chips()
        let selectedId = topVM.getSelectChipId()

        chipScrollView.reload(
            chips: chips,
            selectedId: selectedId,
            dotMode: false,
            compact: true,
            creatingChip: topVM.editingNewChip,
            makeConfig: { [weak self] chip, isSelected, dotMode in
                Self.chipConfig(chip, selected: isSelected, dotMode: dotMode, topVM: topVM, owner: self)
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

    private static func chipConfig(
        _ chip: CategoryChip, selected isSelected: Bool, dotMode: Bool,
        topVM: TopBarViewModel, owner: FloatingHeaderView?
    ) -> ChipButton.Config {
        let isEditing = topVM.editingChipId == chip.id
        return .init(
            chip: chip,
            isSelected: isSelected,
            dotMode: dotMode,
            compact: true,
            isEditing: isEditing,
            editingName: isEditing ? topVM.editingChipName : chip.name,
            editingColorIndex: isEditing ? topVM.editingChipColorIndex : chip.colorIndex,
            action: { [weak owner] in
                owner?.chipScrollView.selectedChipId = chip.id
                owner?.chipScrollView.onSelectionChanged?(chip.id)
            },
            onEdit: { [weak owner] in
                topVM.startEditingChip(chip)
                owner?.reloadChips()
            },
            onDelete: { [weak owner] in
                owner?.confirmDeleteChip(chip)
            },
            onColorChange: { [weak owner] colorIndex in
                topVM.updateChip(chip, colorIndex: colorIndex)
                owner?.reloadChips()
            },
            onEditingNameChange: { text in
                topVM.editingChipName = text
            },
            onEditingSubmit: { [weak owner] in
                topVM.commitEditingChip()
                owner?.reloadChips()
            },
            onEditingCancel: { [weak owner] in
                topVM.cancelEditingChip()
                owner?.reloadChips()
            },
            onEditingFocusChange: { [weak owner] focused in
                owner?.onChipEditingFocusChange?(focused)
            },
            onDrop: { [weak owner] model in
                owner?.topVM?.assignModelToChip(model: model, chipId: chip.id) ?? false
            }
        )

    }

    // MARK: - New Chip Creation

    func startCreatingChip() {
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

    func appendNewChipPlaceholder() {
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

    func refreshNewChipPlaceholder() {
        guard let topVM, topVM.editingNewChip else { return }
        chipScrollView.removeNewChipButton()
        appendNewChipPlaceholder()
    }

    func commitNewChip() {
        endNewChip(commit: true)
    }

    func cancelNewChip() {
        endNewChip(commit: false)
    }

    func endNewChip(commit: Bool) {
        guard let topVM, topVM.editingNewChip else { return }
        topVM.editingNewChip = false
        topVM.commitNewChipOrCancel(commitIfNonEmpty: commit)
        reloadChips()
        if commit {
            onChipSelected?()
        }
    }

    func confirmDeleteChip(_ chip: CategoryChip) {
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

}
