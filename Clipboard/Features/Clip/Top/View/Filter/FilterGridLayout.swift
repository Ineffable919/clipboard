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

        let gridView = PersistentFilterGridView()
        container.addSubview(gridView)
        gridView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        gridView.setItems(
            buttons.enumerated().map { .init(button: $0.element, position: $0.offset) },
            visible: buttons
        )

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

            for item in items where oldPositions[ObjectIdentifier(item.button)] == nil {
                addSubview(item.button)
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

    override func layout() {
        super.layout()
        for item in items {
            let column = item.position % columnCount
            let row = item.position / columnCount
            item.button.frame = NSRect(
                x: CGFloat(column) * (buttonSize.width + spacing),
                y: CGFloat(row) * (buttonSize.height + spacing),
                width: buttonSize.width,
                height: buttonSize.height
            )
        }
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
