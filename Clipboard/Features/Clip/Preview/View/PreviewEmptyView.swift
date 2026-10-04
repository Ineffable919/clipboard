//
//  PreviewEmptyView.swift
//  Clipboard
//
//  无可用内容时的预览占位。
//

import AppKit
import SnapKit

final class PreviewEmptyView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        let label = NSTextField(labelWithString: String(localized: .noPreview))
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        addSubview(label)
        label.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}
