//
//  FilterTagSectionView.swift
//  Clipboard
//
//  分组筛选区域：管理分组按钮的创建、布局和多选状态
//

import AppKit
import SnapKit

final class FilterTagSectionView: NSStackView {
    // MARK: - Callbacks

    var onGroupToggle: ((Int) -> Void)?

    // MARK: - State

    private var selectedGroupIds: Set<Int> = []
    private var availableGroups: [CategoryChip] = []
    private var groupButtons: [Int: FilterTagButton] = [:]

    // MARK: - Views

    private let titleLabel = NSTextField()
    private let gridContainer = NSView()

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        orientation = .vertical
        alignment = .leading
        spacing = Const.space8

        titleLabel.stringValue = String(localized: .tag)
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false

        addArrangedSubview(titleLabel)
        addArrangedSubview(gridContainer)
    }

    // MARK: - Public API

    func setAvailableGroups(_ groups: [CategoryChip]) {
        guard groups != availableGroups else { return }

        availableGroups = groups
        rebuildGrid()
    }

    func updateSelection(_ groupIds: Set<Int>) {
        selectedGroupIds = groupIds
        for (id, button) in groupButtons {
            button.isSelected = groupIds.contains(id)
        }
    }

    // MARK: - Grid

    private func rebuildGrid() {
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        groupButtons.removeAll()

        guard !availableGroups.isEmpty else {
            isHidden = true
            return
        }

        isHidden = false

        var buttons: [FilterButton] = []
        for chip in availableGroups {
            let button = FilterTagButton(
                colorIndex: chip.colorIndex,
                title: chip.name,
                groupId: chip.id
            )
            let capturedId = chip.id
            button.action = { [weak self] in
                self?.onGroupToggle?(capturedId)
            }
            button.isSelected = selectedGroupIds.contains(chip.id)
            groupButtons[chip.id] = button
            buttons.append(button)
        }

        FilterGridLayout.layoutThreeColumnGrid(buttons: buttons, in: gridContainer)
    }
}
