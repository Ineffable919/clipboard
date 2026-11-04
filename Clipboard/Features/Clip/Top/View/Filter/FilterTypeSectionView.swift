//
//  FilterTypeSectionView.swift
//  Clipboard
//
//  类型筛选区域：管理类型按钮的创建和选中状态
//

import AppKit

final class FilterTypeSectionView: FilterSectionView {
    // MARK: - Callbacks

    var onTypeToggle: ((PasteModelType) -> Void)?
    /// 文本按钮同时代表 .string 和 .rich，由外部统一处理
    var onTextToggle: (() -> Void)?

    // MARK: - State

    private var typeButtons: [PasteModelType: FilterButton] = [:]

    // MARK: - Init

    init() {
        super.init(title: String(localized: .type))
        buildButtons()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Public API

    func updateSelection(_ types: Set<PasteModelType>) {
        for (type, button) in typeButtons {
            button.isSelected = type == .string
                ? types.contains(.string) || types.contains(.rich)
                : types.contains(type)
        }
    }

    // MARK: - Buttons

    private func buildButtons() {
        let types: [PasteModelType] = [.color, .file, .image, .link, .string]
        var buttons: [FilterButton] = []
        for type in types {
            let button: FilterButton
            if type == .string {
                var iconText = "doc.text"
                if #available(macOS 15.0, *) {
                    iconText = "text.document"
                }
                button = FilterButton(icon: iconText, title: String(localized: .text))
                button.onTap = { [weak self] in
                    self?.onTextToggle?()
                }
            } else {
                let (icon, label) = type.iconAndLabel
                button = FilterButton(icon: icon, title: label)
                button.onTap = { [weak self] in
                    self?.onTypeToggle?(type)
                }
            }
            typeButtons[type] = button
            buttons.append(button)
        }
        setButtons(buttons)
    }
}
