//
//  EmptyStateView.swift
//  Clipboard
//
//  Created by crown on 2026/4/17.
//

import Cocoa
import SnapKit

class EmptyStateView: NSView {
    enum Style {
        case main
        case floating
    }

    let style: Style

    // MARK: - UI Elements

    private lazy var iconImageView: NSImageView = {
        let iv = NSImageView()
        iv.contentTintColor = NSColor.controlAccentColor.withAlphaComponent(0.8)
        return iv
    }()

    private lazy var titleLabel: NSTextField = {
        let tf = NSTextField(labelWithString: String(localized: .emptyHistory))
        tf.textColor = .secondaryLabelColor
        tf.alignment = .center
        return tf
    }()

    private lazy var hintLabel: NSTextField = {
        let tf = NSTextField(labelWithString: String(localized: .emptyHint))
        tf.textColor = .secondaryLabelColor
        tf.alignment = .center
        if style == .floating {
            tf.font = .systemFont(ofSize: NSFont.systemFontSize)
        } else {
            tf.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        }
        return tf
    }()

    // MARK: - Initialization

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var iconSize: CGFloat {
        style == .main ? 64.0 : 48.0
    }

    // MARK: - Setup

    private func setupViews() {
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(hintLabel)

        let symbolName = if #available(macOS 15.0, *) {
            "heart.text.clipboard.fill"
        } else {
            "list.clipboard.fill"
        }

        iconImageView.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )

        if let symbolImage = iconImageView.image {
            iconImageView.image = symbolImage.withSymbolConfiguration(
                .init(pointSize: iconSize, weight: .regular)
            )
        }
    }

    private func setupConstraints() {
        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.lessThanOrEqualToSuperview()
            make.width.height.equalTo(iconSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(iconImageView.snp.bottom).offset(Const.space20)
        }

        hintLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(Const.space20)
            make.bottom.lessThanOrEqualToSuperview().offset(-20)
        }
    }

    override var acceptsFirstResponder: Bool {
        true
    }
}
