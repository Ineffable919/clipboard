//
//  FilterTypeSectionView.swift
//  Clipboard
//
//  类型筛选区域：管理类型按钮的创建、布局和选中状态
//

import AppKit
import SnapKit

final class FilterTypeSectionView: NSStackView {
    // MARK: - Callbacks

    var onTypeToggle: ((PasteModelType) -> Void)?

    // MARK: - State

    private var selectedTypes: Set<PasteModelType> = []
    private var availableTypes: [PasteModelType] = []
    private var typeButtons: [PasteModelType: FilterButton] = [:]

    // MARK: - Views

    private let titleLabel = NSTextField()
    private let gridContainer = NSView()

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        orientation = .vertical
        alignment = .leading
        spacing = Const.space8

        titleLabel.stringValue = String(localized: .type)
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false

        addArrangedSubview(titleLabel)
        addArrangedSubview(gridContainer)
    }

    // MARK: - Public API

    func setAvailableTypes(_ types: [PasteModelType]) {
        guard availableTypes != types else { return }
        availableTypes = types
        rebuildGrid()
    }

    func updateSelection(_ types: Set<PasteModelType>) {
        selectedTypes = types
        for (type, button) in typeButtons {
            if type == .string {
                button.isSelected = types.contains(.string) || types.contains(.rich)
            } else {
                button.isSelected = types.contains(type)
            }
        }
    }

    // MARK: - Grid

    private func rebuildGrid() {
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        typeButtons.removeAll()

        guard !availableTypes.isEmpty else {
            isHidden = true
            return
        }

        isHidden = false

        var buttons: [FilterButton] = []
        for type in availableTypes {
            let button: FilterButton
            if type == .string {
                // 文本按钮同时代表 .string 和 .rich，选中态任一存在即高亮
                var iconText = "doc.text"
                if #available(macOS 15.0, *) {
                    iconText = "text.document"
                }
                button = FilterButton(icon: iconText, title: String(localized: .text))
                button.action = { [weak self] in
                    self?.onTypeToggle?(.string)
                    self?.onTypeToggle?(.rich)
                }
                button.isSelected = selectedTypes.contains(.string) || selectedTypes.contains(.rich)
            } else if type == .rich {
                // .rich 由文本按钮统一控制，不单独渲染
                continue
            } else {
                let (icon, label) = type.iconAndLabel
                button = FilterButton(icon: icon, title: label)
                let capturedType = type
                button.action = { [weak self] in
                    self?.onTypeToggle?(capturedType)
                }
                button.isSelected = selectedTypes.contains(type)
            }
            typeButtons[type] = button
            buttons.append(button)
        }

        FilterGridLayout.layoutThreeColumnGrid(buttons: buttons, in: gridContainer)
    }
}
