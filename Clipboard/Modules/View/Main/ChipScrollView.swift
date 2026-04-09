//
//  ChipScrollView.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit

final class ChipScrollView: NSView {

    // MARK: - Properties

    private let scrollView = NSScrollView()
    private let contentStack = NSStackView()

    private var chips: [CategoryChip] = []
    private var chipButtons: [ChipButton] = []

    var selectedChipId: Int = -1 {
        didSet {
            guard oldValue != selectedChipId else { return }
            syncSelection()
        }
    }

    var onSelectionChanged: ((Int) -> Void)?

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let clipView = NSClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        contentStack.orientation = .horizontal
        contentStack.spacing = Const.space6
        contentStack.alignment = .centerY
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentStack

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: clipView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: clipView.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
        ])

        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // MARK: - Public API

    /// - Parameters:
    ///   - dotMode: `true` 时每个 chip 渲染为小圆点（搜索模式），`false` 为完整胶囊（默认模式）
    func reload(chips: [CategoryChip], selectedId: Int, dotMode: Bool = false) {
        self.chips = chips
        self.selectedChipId = selectedId

        chipButtons.forEach { $0.removeFromSuperview() }
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        chipButtons = []

        for chip in chips {
            let btn = ChipButton(config: .init(
                chip: chip,
                isSelected: chip.id == selectedId,
                dotMode: dotMode,
                action: { [weak self] in self?.select(id: chip.id) }
            ))
            chipButtons.append(btn)
            contentStack.addArrangedSubview(btn)
        }
    }

    // MARK: - Private

    private func select(id: Int) {
        selectedChipId = id
        onSelectionChanged?(id)
    }

    private func syncSelection() {
        for (btn, chip) in zip(chipButtons, chips) {
            btn.isSelected = chip.id == selectedChipId
        }
    }
}
