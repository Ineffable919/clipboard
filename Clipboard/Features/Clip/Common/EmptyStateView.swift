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
        let image = NSImageView()
        image.contentTintColor = NSColor.controlAccentColor.withAlphaComponent(0.8)
        return image
    }()

    private lazy var titleLabel: NSTextField = {
        let field = NSTextField(labelWithString: String(localized: .emptyRecord))
        field.textColor = .secondaryLabelColor
        field.alignment = .center
        return field
    }()

    private lazy var hintLabel: NSTextField = {
        let field = NSTextField(labelWithString: String(localized: .emptyHint))
        field.textColor = .secondaryLabelColor
        field.alignment = .center
        if style == .floating {
            field.font = .systemFont(ofSize: NSFont.systemFontSize)
        } else {
            field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        }
        return field
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

        let symbolName =
            if #available(macOS 26.0, *) {
                "sparkle.text.clipboard"
            } else if #available(macOS 15.0, *) {
                "heart.text.clipboard"
            } else {
                "list.clipboard"
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
            if style == .main {
                make.top.equalToSuperview()
            } else {
                make.top.lessThanOrEqualToSuperview()
            }
            make.width.height.equalTo(iconSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(iconImageView.snp.bottom).offset(Const.space20)
        }

        hintLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(Const.space20)
            if style == .main {
                make.bottom.equalToSuperview()
            } else {
                make.bottom.lessThanOrEqualToSuperview()
            }
        }
    }

    override var acceptsFirstResponder: Bool {
        true
    }
}
