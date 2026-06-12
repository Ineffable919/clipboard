//
//  FilterDateSectionView.swift
//  Clipboard
//
//  日期筛选区域：管理日期按钮的创建、布局和选中状态
//

import AppKit
import SnapKit

final class FilterDateSectionView: NSStackView {
    // MARK: - Callbacks

    var onDateFilterChange: ((DateFilterOption?) -> Void)?

    // MARK: - State

    private var selectedDateFilter: DateFilterOption?
    private var dateButtons: [DateFilterOption: FilterButton] = [:]

    // MARK: - Views

    private let titleLabel = NSTextField()
    private let gridContainer = NSView()

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        setup()
        rebuildGrid()
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

        titleLabel.stringValue = String(localized: .date)
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

    func updateSelection(_ dateFilter: DateFilterOption?) {
        selectedDateFilter = dateFilter
        for (option, button) in dateButtons {
            button.isSelected = option == dateFilter
        }
    }

    // MARK: - Grid

    private func rebuildGrid() {
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        dateButtons.removeAll()

        var buttons: [FilterButton] = []
        for option in DateFilterOption.allCases {
            let button = FilterButton(icon: "calendar", title: option.displayName)
            button.action = { [weak self] in
                guard let self else { return }
                if selectedDateFilter == option {
                    onDateFilterChange?(nil)
                } else {
                    onDateFilterChange?(option)
                }
            }
            button.isSelected = selectedDateFilter == option
            dateButtons[option] = button
            buttons.append(button)
        }

        FilterGridLayout.layoutThreeColumnGrid(buttons: buttons, in: gridContainer)
    }
}
