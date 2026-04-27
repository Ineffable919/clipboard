//
//  FilterGridLayout.swift
//  Clipboard
//
//  三列网格布局工具，供各 Section 共用
//

import AppKit
import SnapKit

enum FilterGridLayout {
    /// 三列网格布局
    static func layoutThreeColumnGrid(buttons: [FilterButton], in container: NSView) {
        container.subviews.forEach { $0.removeFromSuperview() }

        let columnCount = 3
        let spacing = Const.space8
        let buttonWidth: CGFloat = 140
        let buttonHeight: CGFloat = 30

        let gridView = NSGridView()
        gridView.rowSpacing = spacing
        gridView.columnSpacing = spacing
        gridView.xPlacement = .leading
        gridView.yPlacement = .center

        container.addSubview(gridView)
        gridView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        var currentRow: [NSView] = []
        for (index, button) in buttons.enumerated() {
            button.snp.makeConstraints { make in
                make.width.equalTo(buttonWidth)
                make.height.equalTo(buttonHeight)
            }

            currentRow.append(button)

            if currentRow.count == columnCount || index == buttons.count - 1 {
                while currentRow.count < columnCount {
                    let spacer = NSView()
                    spacer.snp.makeConstraints { make in
                        make.width.equalTo(buttonWidth)
                        make.height.equalTo(buttonHeight)
                    }
                    currentRow.append(spacer)
                }

                gridView.addRow(with: currentRow)
                currentRow.removeAll()
            }
        }

        container.snp.remakeConstraints { make in
            make.width.equalToSuperview()
        }
    }
}
