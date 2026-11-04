//
//  FilterTagSectionView.swift
//  Clipboard
//
//  分组筛选区域：管理分组按钮的创建和多选状态
//

import AppKit

final class FilterTagSectionView: FilterSectionView {
    // MARK: - Callbacks

    var onGroupToggle: ((Int) -> Void)?

    // MARK: - State

    private var selectedGroupIds: Set<Int> = []
    private var availableGroups: [CategoryChip] = []
    private var groupButtons: [Int: FilterTagButton] = [:]

    // MARK: - Init

    init() {
        super.init(title: String(localized: .tag))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Public API

    func setAvailableGroups(_ groups: [CategoryChip]) {
        guard groups != availableGroups else { return }
        availableGroups = groups

        groupButtons.removeAll()
        var buttons: [FilterButton] = []
        for chip in groups {
            let id = chip.id
            let button = FilterTagButton(
                colorIndex: chip.colorIndex,
                title: chip.name,
                groupId: id
            )
            button.onTap = { [weak self] in
                self?.onGroupToggle?(id)
            }
            button.isSelected = selectedGroupIds.contains(id)
            groupButtons[id] = button
            buttons.append(button)
        }
        setButtons(buttons)
    }

    func updateSelection(_ groupIds: Set<Int>) {
        selectedGroupIds = groupIds
        for (id, button) in groupButtons {
            button.isSelected = groupIds.contains(id)
        }
    }
}
