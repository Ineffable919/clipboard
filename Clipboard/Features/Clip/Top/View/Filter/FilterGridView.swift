//
//  FilterGridView.swift
//  Clipboard
//
//  Created by crown on 2026/11/4
//
//  三列网格：按钮宽度随容器宽度推导，按可见顺序依次排布
//

import AppKit

final class FilterGridView: NSView {
    private let columnCount = 3
    private let spacing = Const.space8
    private let rowHeight: CGFloat = 30

    private var allButtons: [FilterButton] = []
    private var visibleButtons: [FilterButton] = []

    override var isFlipped: Bool {
        true
    }

    /// 设置网格按钮。`all` 决定子视图归属，`visible` 决定显示内容与排布顺序
    func setButtons(all: [FilterButton], visible: [FilterButton]) {
        let oldIDs = Set(allButtons.map { ObjectIdentifier($0) })
        let newIDs = Set(all.map { ObjectIdentifier($0) })
        for button in allButtons where !newIDs.contains(ObjectIdentifier(button)) {
            button.removeFromSuperview()
        }
        for button in all where !oldIDs.contains(ObjectIdentifier(button)) {
            addSubview(button)
        }

        allButtons = all
        visibleButtons = visible
        let visibleIDs = Set(visible.map { ObjectIdentifier($0) })
        for button in all {
            button.isHidden = !visibleIDs.contains(ObjectIdentifier(button))
        }

        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let gaps = spacing * CGFloat(columnCount - 1)
        // 宽度尚未确定（0、负数或非有限值）时不排布，避免写入无效 frame
        guard bounds.width.isFinite, bounds.width > gaps else { return }
        let width = ((bounds.width - gaps) / CGFloat(columnCount)).rounded(.down)
        for (index, button) in visibleButtons.enumerated() {
            button.frame = NSRect(
                x: CGFloat(index % columnCount) * (width + spacing),
                y: CGFloat(index / columnCount) * (rowHeight + spacing),
                width: width,
                height: rowHeight
            )
        }
    }

    override var intrinsicContentSize: NSSize {
        let rows = (visibleButtons.count + columnCount - 1) / columnCount
        let height = rows == 0
            ? 0
            : rowHeight * CGFloat(rows) + spacing * CGFloat(rows - 1)
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }
}
