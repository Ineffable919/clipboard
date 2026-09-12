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
    private var pendingScrollOrigin: NSPoint?

    var selectedChipId: Int = -1 {
        didSet {
            guard oldValue != selectedChipId else { return }
            syncSelection()
        }
    }

    var onSelectionChanged: ((Int) -> Void)?

    var scrollMode: Bool = false

    var maximumWidth: CGFloat = .greatestFiniteMagnitude {
        didSet {
            guard oldValue != maximumWidth else { return }
            invalidateWidth()
        }
    }

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
        if scrollMode {
            return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }
        return NSSize(
            width: min(contentStack.fittingSize.width, maximumWidth),
            height: NSView.noIntrinsicMetric
        )
    }

    private func invalidateWidth() {
        invalidateIntrinsicContentSize()
        needsLayout = true
        superview?.needsLayout = true
    }

    override func layout() {
        super.layout()
        if let origin = pendingScrollOrigin {
            pendingScrollOrigin = nil
            contentStack.scroll(origin)
        }
    }

    private func keepEditingEdgeVisible(_ button: ChipButton) {
        invalidateWidth()
        Task { @MainActor [weak self, weak button] in
            guard let self, let button else { return }
            guard let contentView = window?.contentView else { return }
            contentView.layoutSubtreeIfNeeded()
            let edge = NSRect(
                x: max(button.bounds.maxX - 1, 0),
                y: button.bounds.minY,
                width: 1,
                height: button.bounds.height
            )
            button.scrollToVisible(edge)
        }
    }

    // MARK: - Public API

    func reload(
        chips: [CategoryChip],
        selectedId: Int,
        dotMode: Bool = false,
        compact: Bool = false,
        creatingChip: Bool = false,
        makeConfig: ((CategoryChip, Bool, Bool) -> ChipButton.Config)? = nil
    ) {
        let oldButtons = Dictionary(uniqueKeysWithValues: zip(self.chips.map(\.id), chipButtons))
        let changed = self.chips.map(\.id) != chips.map(\.id)
        let hadPlaceholder = newChipButton != nil
        let animate = !self.chips.isEmpty
            && ((changed && !hadPlaceholder) || (hadPlaceholder && !changed && !creatingChip))

        animateChanges(animate) { animated in
            pendingScrollOrigin = pendingScrollOrigin ?? scrollView.contentView.bounds.origin
            if let placeholder = newChipButton, !creatingChip {
                removeButton(placeholder, animated: animated)
                newChipButton = nil
            }
            let ids = Set(chips.map(\.id))
            for (id, button) in oldButtons where !ids.contains(id) {
                removeButton(button, animated: animated)
            }
            self.chips = chips
            chipButtons = []
            for (index, chip) in chips.enumerated() {
                let config = makeConfig?(chip, chip.id == selectedId, dotMode)
                    ?? .init(
                        chip: chip,
                        isSelected: chip.id == selectedId,
                        dotMode: dotMode,
                        compact: compact,
                        action: { [weak self] in self?.select(id: chip.id) }
                    )
                let button: ChipButton
                if let existing = oldButtons[chip.id] {
                    button = existing
                    button.update(config: config)
                } else {
                    button = makeButton(config: config)
                    insertButton(button, at: index, animated: animated)
                }
                if contentStack.arrangedSubviews.firstIndex(of: button) != index {
                    contentStack.removeArrangedSubview(button)
                    contentStack.insertArrangedSubview(button, at: index)
                }
                chipButtons.append(button)
                if config.isEditing {
                    keepEditingEdgeVisible(button)
                }
            }
            selectedChipId = selectedId
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

    // MARK: - New Chip Placeholder

    func appendNewChipButton(config: ChipButton.Config) {
        if let button = newChipButton {
            button.update(config: config)
            return
        }
        animateChanges(!chips.isEmpty) { animated in
            let button = makeButton(config: config)
            newChipButton = button
            insertButton(button, at: contentStack.arrangedSubviews.count, animated: animated)
            keepEditingEdgeVisible(button)
        }
    }

    func removeNewChipButton() {
        guard let button = newChipButton else { return }
        animateChanges(true) { animated in
            newChipButton = nil
            removeButton(button, animated: animated)
        }
    }

    // MARK: - Scroll To Visible

    func scrollToChip(id: Int) {
        guard scrollMode,
              let index = chips.firstIndex(where: { $0.id == id }),
              index < chipButtons.count
        else { return }
        let btn = chipButtons[index]
        Task { @MainActor in btn.scrollToVisible(btn.bounds) }
    }

    func scrollToEnd() {
        guard scrollMode else { return }
        let target = (newChipButton ?? chipButtons.last)
        guard let target else { return }
        Task { @MainActor in target.scrollToVisible(target.bounds) }
    }
}

private extension ChipScrollView {
    func makeButton(config: ChipButton.Config) -> ChipButton {
        let button = ChipButton(config: config)
        button.onWidthChanged = { [weak self, weak button] in
            guard let button else { return }
            self?.keepEditingEdgeVisible(button)
        }
        return button
    }

    func animateChanges(_ requested: Bool, changes: (Bool) -> Void) {
        guard requested, let window, window.isVisible, !isHiddenOrHasHiddenAncestor,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              let root = window.contentView
        else {
            changes(false)
            invalidateWidth()
            return
        }
        root.layoutSubtreeIfNeeded()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            changes(true)
            invalidateWidth()
            root.layoutSubtreeIfNeeded()
        }
    }

    func insertButton(_ button: ChipButton, at index: Int, animated: Bool) {
        button.frame = NSRect(
            origin: NSPoint(x: contentStack.arrangedSubviews.last?.frame.maxX ?? 0, y: 0),
            size: button.fittingSize
        )
        contentStack.insertArrangedSubview(button, at: index)
        if animated {
            button.alphaValue = 0
            button.animator().alphaValue = 1
        }
    }

    func removeButton(_ button: ChipButton, animated: Bool) {
        contentStack.removeArrangedSubview(button)
        guard animated else {
            button.removeFromSuperview()
            return
        }
        // Keep the outgoing view outside the stack's layout until its fade completes.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            button.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                button.removeFromSuperview()
            }
        }
    }
}
