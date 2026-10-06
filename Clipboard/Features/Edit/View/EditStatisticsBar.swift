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
        let field = NSTextField(wrappingLabelWithString: "")
        field.font = .systemFont(ofSize: 13)
        field.textColor = .secondaryLabelColor
        field.isSelectable = false
        field.maximumNumberOfLines = 2
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
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

    private let progressIndicator = NSProgressIndicator()

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
        addSubview(progressIndicator)
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.setAccessibilityLabel(String(localized: .jsonProcessing))
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Const.space12)
            make.trailing.equalToSuperview().inset(Const.space12)
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
        progressIndicator.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(statusLabel)
            make.size.equalTo(14)
        }
    }

    // MARK: - Public

    func update(_ statistics: TextStatistics) {
        label.stringValue = statistics.displayString
    }

    func setMode(_ mode: EditMode) {
        let isJSON = mode == .json
        if !isJSON { progressIndicator.stopAnimation(nil) }
        statusLabel.isHidden = !isJSON
        positionLabel.isHidden = !isJSON
        label.maximumNumberOfLines = isJSON ? 1 : 2
        label.lineBreakMode = isJSON ? .byTruncatingTail : .byWordWrapping
        label.snp.remakeConstraints { make in
            make.leading.equalToSuperview().inset(Const.space12)
            make.centerY.equalToSuperview()
            if isJSON {
                make.trailing.lessThanOrEqualTo(statusLabel.snp.leading).offset(-Const.space12)
            } else {
                make.trailing.equalToSuperview().inset(Const.space12)
            }
        }
        if isJSON, statusLabel.stringValue.isEmpty {
            setProcessing()
        }
    }

    func setJSONValid(_ valid: Bool) {
        progressIndicator.stopAnimation(nil)
        statusLabel.stringValue = valid
            ? String(localized: .jsonValid)
            : String(localized: .jsonInvalid)
        statusLabel.textColor = valid ? .systemGreen : .systemRed
    }

    func setProcessing() {
        statusLabel.stringValue = ""
        progressIndicator.startAnimation(nil)
    }

    func setError(_ message: String) {
        progressIndicator.stopAnimation(nil)
        statusLabel.stringValue = message
        statusLabel.textColor = .systemRed
    }

    func updateCursor(line: Int, column: Int) {
        positionLabel.stringValue = String(localized: .jsonLineColumn(line, column))
    }
}
