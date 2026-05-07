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

    private let scrollView = HorizontalScrollView()
    private let contentStack = NSStackView()

    private var chips: [CategoryChip] = []
    private var chipButtons: [ChipButton] = []
    private weak var newChipButton: ChipButton?

    var selectedChipId: Int = -1 {
        didSet {
            guard oldValue != selectedChipId else { return }
            syncSelection()
        }
    }

    var onSelectionChanged: ((Int) -> Void)?

    /// 浮动窗口场景：宽度由父视图约束决定，内容超出时滚动；主窗口默认 false（展开到内容宽度）
    var scrollMode: Bool = false

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
        contentStack.spacing = Const.space6 / 2
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
        if scrollMode { return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric) }
        return NSSize(width: contentStack.fittingSize.width, height: NSView.noIntrinsicMetric)
    }

    private func invalidateWidth() {
        invalidateIntrinsicContentSize()
        superview?.needsLayout = true
    }

    // MARK: - Public API

    func reload(
        chips: [CategoryChip],
        selectedId: Int,
        dotMode: Bool = false,
        compact: Bool = false,
        makeConfig: ((CategoryChip, Bool, Bool) -> ChipButton.Config)? = nil
    ) {
        self.chips = chips
        newChipButton = nil

        chipButtons.forEach { $0.removeFromSuperview() }
        for arrangedSubview in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }
        chipButtons = []

        for chip in chips {
            let isSelected = chip.id == selectedId
            let config =
                makeConfig?(chip, isSelected, dotMode)
                    ?? .init(
                        chip: chip,
                        isSelected: isSelected,
                        dotMode: dotMode,
                        compact: compact,
                        action: { [weak self] in
                            self?.select(id: chip.id)
                        }
                    )
            let btn = ChipButton(config: config)
            btn.onWidthChanged = { [weak self] in
                self?.invalidateWidth()
            }
            chipButtons.append(btn)
            contentStack.addArrangedSubview(btn)
        }

        selectedChipId = selectedId
        invalidateWidth()
        scrollView.documentView?.scroll(.zero)
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

    // MARK: - New Chip Placeholder

    func appendNewChipButton(config: ChipButton.Config) {
        removeNewChipButton()
        let btn = ChipButton(config: config)
        btn.onWidthChanged = { [weak self] in
            self?.invalidateWidth()
        }
        newChipButton = btn
        contentStack.addArrangedSubview(btn)
        invalidateWidth()
    }

    func removeNewChipButton() {
        guard let btn = newChipButton else { return }
        contentStack.removeArrangedSubview(btn)
        btn.removeFromSuperview()
        newChipButton = nil
        invalidateWidth()
    }
}
