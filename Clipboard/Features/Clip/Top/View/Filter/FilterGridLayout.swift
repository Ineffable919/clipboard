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
            button.snp.remakeConstraints { make in
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

final class PersistentFilterGridView: NSView {
    struct Item {
        let button: FilterButton
        let position: Int
    }

    private let columnCount = 3
    private let spacing = Const.space8
    private let buttonSize = NSSize(width: 140, height: 30)

    private var items: [Item] = []
    private var visibleButtons: [FilterButton] = []

    override var isFlipped: Bool {
        true
    }

    func setItems(
        _ items: [Item],
        visible visibleButtons: [FilterButton]
    ) {
        let oldPositions = Dictionary(uniqueKeysWithValues: self.items.map {
            (ObjectIdentifier($0.button), $0.position)
        })
        let newPositions = Dictionary(uniqueKeysWithValues: items.map {
            (ObjectIdentifier($0.button), $0.position)
        })

        if oldPositions != newPositions {
            for item in self.items where newPositions[ObjectIdentifier(item.button)] == nil {
                item.button.removeFromSuperview()
            }

            for item in items {
                let identifier = ObjectIdentifier(item.button)
                let oldPosition = oldPositions[identifier]
                if oldPosition == nil {
                    addSubview(item.button)
                }
                guard oldPosition != item.position else { continue }

                let column = item.position % columnCount
                let row = item.position / columnCount
                item.button.snp.remakeConstraints { make in
                    make.leading.equalToSuperview().offset(
                        CGFloat(column) * (buttonSize.width + spacing)
                    )
                    make.top.equalToSuperview().offset(
                        CGFloat(row) * (buttonSize.height + spacing)
                    )
                    make.width.equalTo(buttonSize.width)
                    make.height.equalTo(buttonSize.height)
                }
            }
            self.items = items
        }

        self.visibleButtons = visibleButtons
        let visibleIdentifierSet = Set(visibleButtons.map { ObjectIdentifier($0) })
        for item in items {
            item.button.isHidden = !visibleIdentifierSet.contains(
                ObjectIdentifier(item.button)
            )
        }

        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override var intrinsicContentSize: NSSize {
        guard !visibleButtons.isEmpty else {
            return .zero
        }

        let rowCount = (visibleButtons.count + columnCount - 1) / columnCount
        let width = buttonSize.width * CGFloat(columnCount)
            + spacing * CGFloat(columnCount - 1)
        let height = buttonSize.height * CGFloat(rowCount)
            + spacing * CGFloat(rowCount - 1)
        return NSSize(width: width, height: height)
    }
}
