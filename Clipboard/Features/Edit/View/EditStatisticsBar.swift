//
//  EditStatisticsBar.swift
//  Clipboard
//
//  编辑窗口底部统计栏（字符数 / 词数 / 行数）
//

import AppKit
import SnapKit

final class EditStatisticsBar: NSView {
    // MARK: - Subviews

    private let label: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: 13)
        f.textColor = .secondaryLabelColor
        f.lineBreakMode = .byTruncatingTail
        return f
    }()

    private let statusLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: 12, weight: .medium)
        field.lineBreakMode = .byTruncatingTail
        field.isHidden = true
        return field
    }()

    private let positionLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        field.textColor = .secondaryLabelColor
        field.isHidden = true
        return field
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
        addSubview(label)
        addSubview(statusLabel)
        addSubview(positionLabel)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Const.space12)
            make.trailing.lessThanOrEqualTo(statusLabel.snp.leading).offset(-Const.space12)
            make.centerY.equalToSuperview()
        }

        statusLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(positionLabel.snp.leading).offset(-Const.space12)
        }

        positionLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(Const.space12)
        }
    }

    // MARK: - Public

    func update(_ statistics: TextStatistics) {
        label.stringValue = statistics.displayString
    }

    func setMode(_ mode: EditMode) {
        let isJSON = mode == .json
        statusLabel.isHidden = !isJSON
        positionLabel.isHidden = !isJSON
        if isJSON, statusLabel.stringValue.isEmpty {
            setProcessing()
        }
    }

    func setJSONValid(_ valid: Bool) {
        statusLabel.stringValue = valid
            ? String(localized: .jsonValid)
            : String(localized: .jsonInvalid)
        statusLabel.textColor = valid ? .systemGreen : .systemRed
    }

    func setProcessing() {
        statusLabel.stringValue = String(localized: .jsonProcessing)
        statusLabel.textColor = .secondaryLabelColor
    }

    func setError(_ message: String) {
        statusLabel.stringValue = message
        statusLabel.textColor = .systemRed
    }

    func updateCursor(line: Int, column: Int) {
        positionLabel.stringValue = String(localized: .jsonLineColumn(line, column))
    }
}
