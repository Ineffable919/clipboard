//
//  FilterTagButton.swift
//  Clipboard
//
//  标签筛选按钮：左边颜色圆点 + 右边文案
//

import AppKit
import SnapKit

final class FilterTagButton: FilterButton {
    let groupId: Int

    init(colorIndex: Int, title: String, groupId: Int) {
        self.groupId = groupId
        super.init(icon: nil, title: title)
        setupDot(colorIndex: colorIndex)
    }

    private func setupDot(colorIndex: Int) {
        let dotContainer = NSView()
        let diameter = CategoryDotRenderer.diameter
        let origin = (20 - diameter) / 2
        let dotView = NSView(frame: NSRect(
            x: origin,
            y: origin,
            width: diameter,
            height: diameter
        ))
        CategoryDotRenderer.configure(dotView, colorIndex: colorIndex)
        dotContainer.addSubview(dotView)
        setLeadingView(dotContainer)
    }
}
