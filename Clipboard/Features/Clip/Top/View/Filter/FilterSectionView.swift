//
//  FilterSectionView.swift
//  Clipboard
//
//  Created by crown on 2026/11/4
//
//  筛选区域基类：标题 + 三列按钮网格
//

import AppKit
import SnapKit

class FilterSectionView: NSStackView {
    private let grid = FilterGridView()

    init(title: String) {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = Const.space8

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        addArrangedSubview(titleLabel)
        addArrangedSubview(grid)
        grid.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    /// 更新网格；没有可见按钮时隐藏整个区域
    final func setButtons(all: [FilterButton], visible: [FilterButton]) {
        grid.setButtons(all: all, visible: visible)
        isHidden = visible.isEmpty
    }

    final func setButtons(_ buttons: [FilterButton]) {
        setButtons(all: buttons, visible: buttons)
    }
}
