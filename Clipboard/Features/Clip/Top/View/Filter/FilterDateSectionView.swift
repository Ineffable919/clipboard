//
//  FilterDateSectionView.swift
//  Clipboard
//
//  日期筛选区域：管理日期按钮的创建和选中状态
//

import AppKit

final class FilterDateSectionView: FilterSectionView {
    // MARK: - Callbacks

    var onDateFilterChange: ((DateFilterOption?) -> Void)?

    // MARK: - State

    private var selectedDateFilter: DateFilterOption?
    private var dateButtons: [DateFilterOption: FilterButton] = [:]

    // MARK: - Init

    init() {
        super.init(title: String(localized: .date))
        buildButtons()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Public API

    func updateSelection(_ dateFilter: DateFilterOption?) {
        selectedDateFilter = dateFilter
        for (option, button) in dateButtons {
            button.isSelected = option == dateFilter
        }
    }

    // MARK: - Buttons

    private func buildButtons() {
        var buttons: [FilterButton] = []
        for option in DateFilterOption.allCases {
            let button = FilterButton(icon: "calendar", title: option.displayName)
            button.onTap = { [weak self] in
                guard let self else { return }
                onDateFilterChange?(selectedDateFilter == option ? nil : option)
            }
            dateButtons[option] = button
            buttons.append(button)
        }
        setButtons(buttons)
    }
}
