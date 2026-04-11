//
//  ChipScrollView.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import SnapKit

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
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true

        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none

        let clipView = NSClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        contentStack.orientation = .horizontal
        contentStack.spacing = Const.space6
        contentStack.alignment = .centerY
        scrollView.documentView = contentStack

        contentStack.snp.makeConstraints { make in
            make.top.bottom.leading.equalTo(clipView)
        }

        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Intrinsic Content Size

    override var intrinsicContentSize: NSSize {
        let width = contentStack.fittingSize.width
        return NSSize(width: width, height: NSView.noIntrinsicMetric)
    }

    private func invalidateWidth() {
        invalidateIntrinsicContentSize()
    }

    // MARK: - Public API

    func reload(chips: [CategoryChip], selectedId: Int, dotMode: Bool = false) {
        self.chips = chips
        selectedChipId = selectedId

        chipButtons.forEach { $0.removeFromSuperview() }
        for arrangedSubview in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }
        chipButtons = []

        for chip in chips {
            let btn = ChipButton(
                config: .init(
                    chip: chip,
                    isSelected: chip.id == selectedId,
                    dotMode: dotMode,
                    action: { [weak self] in
                        self?.select(id: chip.id)
                    }
                )
            )
            chipButtons.append(btn)
            contentStack.addArrangedSubview(btn)
        }

        invalidateWidth()
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
