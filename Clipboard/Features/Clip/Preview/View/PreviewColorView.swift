//
//  PreviewColorView.swift
//  Clipboard
//
//  颜色值预览。
//

import AppKit
import SnapKit

final class PreviewColorView: NSView {
    init(model: PasteboardModel) {
        super.init(frame: .zero)
        wantsLayer = true

        let (backgroundColor, foregroundColor) = model.colors()
        layer?.backgroundColor = backgroundColor.cgColor

        let label = NSTextField(labelWithString: model.colorDisplayText)
        label.font = .systemFont(ofSize: NSFont.systemFontSize * 1.7, weight: .medium)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.textColor = foregroundColor

        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Const.space12)
            make.trailing.lessThanOrEqualToSuperview().offset(-Const.space12)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}
