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
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Const.space12)
            make.trailing.lessThanOrEqualToSuperview().inset(Const.space12)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Public

    func update(_ statistics: TextStatistics) {
        label.stringValue = statistics.displayString
    }
}
