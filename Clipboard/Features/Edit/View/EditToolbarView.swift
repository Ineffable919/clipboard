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
    var onModeChange: ((EditMode) -> Void)?
    var onJSONAction: ((JSONToolAction) -> Void)?
    var onIndentationChange: ((JSONIndentation) -> Void)?

    // MARK: - Subviews

    private let cancelButton = PreviewPillButton(
        title: String(localized: .commonCancel),
        style: .secondary
    )

    private let saveButton = PreviewPillButton(
        title: String(localized: .save),
        style: .primary
    )

    private let modeButton = EditFormatButton(symbolName: "curlybraces")
    private let jsonToolbar = JSONToolbarView()

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

    private var mode = EditMode.text

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
        modeButton.action = { [weak self] in self?.toggleMode() }
        jsonToolbar.onAction = { [weak self] action in
            self?.onJSONAction?(action)
        }
        jsonToolbar.onIndentationChange = { [weak self] indentation in
            self?.onIndentationChange?(indentation)
        }

        addSubview(cancelButton)
        addSubview(modeButton)
        addSubview(saveButton)

        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Const.space12)
            make.centerY.equalToSuperview()
        }

        modeButton.snp.makeConstraints { make in
            make.leading.equalTo(cancelButton.snp.trailing).offset(Const.space8)
            make.centerY.equalToSuperview()
        }

        saveButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Const.space12)
            make.centerY.equalToSuperview()
        }

        setMode(.text)
    }

    private func makeFormatButton(symbol: String, action: FormatAction) -> EditFormatButton {
        let button = EditFormatButton(symbolName: symbol)
        button.action = { [weak self] in self?.onFormat?(action) }
        return button
    }

    func setMode(_ mode: EditMode) {
        self.mode = mode
        let isJSON = mode == .json
        installModeToolbar(isJSON ? jsonToolbar : formatStack)
        let modeTooltip = isJSON
            ? String(localized: .textModeTooltip)
            : String(localized: .jsonModeTooltip)
        modeButton.toolTip = modeTooltip
        modeButton.setAccessibilityLabel(modeTooltip)
        modeButton.setSymbol(isJSON ? "square.and.pencil" : "curlybraces")
    }

    private func installModeToolbar(_ toolbar: NSView) {
        guard toolbar.superview !== self else { return }

        formatStack.removeFromSuperview()
        jsonToolbar.removeFromSuperview()
        addSubview(toolbar)
        toolbar.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualTo(modeButton.snp.trailing).offset(Const.space8)
            make.trailing.lessThanOrEqualTo(saveButton.snp.leading).offset(-Const.space8)
        }
    }

    func setJSONToolsEnabled(_ enabled: Bool) {
        jsonToolbar.setEnabled(enabled)
    }

    private func toggleMode() {
        onModeChange?(mode == .text ? .json : .text)
    }
}
