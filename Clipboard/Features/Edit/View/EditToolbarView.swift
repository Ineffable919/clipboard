//
//  EditToolbarView.swift
//  Clipboard
//
//  编辑窗口顶部工具栏：取消 + 格式化 + 保存
//

import AppKit
import SnapKit

final class EditToolbarView: NSView {
    // MARK: - Callbacks

    var onCancel: (() -> Void)?
    var onSave: (() -> Void)?
    var onFormat: ((FormatAction) -> Void)?

    // MARK: - Subviews

    private let cancelButton = PreviewPillButton(
        title: String(localized: .commonCancel),
        style: .secondary
    )

    private let saveButton = PreviewPillButton(
        title: String(localized: .save),
        style: .primary
    )

    private lazy var formatStack: NSStackView = {
        let stack = NSStackView(views: [
            makeFormatButton(symbol: "bold", action: .bold),
            makeFormatButton(symbol: "italic", action: .italic),
            makeFormatButton(symbol: "underline", action: .underline),
            makeFormatButton(symbol: "strikethrough", action: .strikethrough),
        ])
        stack.orientation = .horizontal
        stack.spacing = Const.space8
        stack.alignment = .centerY
        return stack
    }()

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        cancelButton.onAction = { [weak self] in self?.onCancel?() }
        saveButton.onAction = { [weak self] in self?.onSave?() }

        addSubview(cancelButton)
        addSubview(formatStack)
        addSubview(saveButton)

        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Const.space12)
            make.centerY.equalToSuperview()
        }

        saveButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Const.space12)
            make.centerY.equalToSuperview()
        }

        formatStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func makeFormatButton(symbol: String, action: FormatAction) -> EditFormatButton {
        let button = EditFormatButton(symbolName: symbol)
        button.action = { [weak self] in self?.onFormat?(action) }
        return button
    }
}
