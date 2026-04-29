//
//  FilterGroupButton.swift
//  Clipboard
//
//  分组筛选按钮：左边颜色圆点 + 右边文案
//

import AppKit
import SnapKit

final class FilterGroupButton: FilterButton {
    let groupId: Int

    init(colorIndex: Int, title: String, groupId: Int) {
        self.groupId = groupId
        super.init(icon: nil, title: title)
        setupDot(colorIndex: colorIndex)
    }

    private func setupDot(colorIndex: Int) {
        let dotContainer = NSView()
        dotContainer.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }

        let dotView = NSView()
        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 6
        let color = CategoryChip.nsColor(at: colorIndex)
        dotView.layer?.backgroundColor = color.cgColor
        dotContainer.addSubview(dotView)
        dotView.snp.makeConstraints { make in
            make.width.height.equalTo(12)
            make.center.equalToSuperview()
        }

        stack.insertArrangedSubview(dotContainer, at: 0)
    }
}
