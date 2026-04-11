//
//  CardHeadView.swift
//  Clipboard
//
//

import AppKit
import SnapKit
import SwiftUI

final class CardHeadView: NSView {
    private var iconLoadTask: Task<Void, Never>?

    // MARK: - Subviews

    private lazy var backgroundView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        return view
    }()

    private lazy var typeLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.textColor = .white
        field.font = .systemFont(ofSize: 15)
        field.lineBreakMode = .byTruncatingTail
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }()

    private lazy var timestampLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: 12)
        field.textColor = NSColor.white.withAlphaComponent(0.85)
        field.lineBreakMode = .byTruncatingTail
        return field
    }()

    private lazy var textStack: NSStackView = {
        let stack = NSStackView(views: [typeLabel, timestampLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.distribution = .fill
        return stack
    }()

    private lazy var iconView: NSImageView = {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.isHidden = true
        return view
    }()

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Configure

    func configure(with model: PasteboardModel) {
        let isDefault = model.group == -1

        let color = NSColor(AppColorService.shared.color(for: model))
        backgroundView.layer?.backgroundColor = color.cgColor

        typeLabel.stringValue = model.type.string

        timestampLabel.isHidden = !isDefault
        if isDefault {
            timestampLabel.stringValue = model.timestamp.timeAgo(
                relativeTo: TimeManager.shared.currentTime
            )
        }

        iconView.isHidden = !isDefault
        if isDefault {
            iconView.image = AppIconCache.shared.getCachedIcon(forPath: model.appPath)
            iconLoadTask?.cancel()
            iconLoadTask = Task { @MainActor [weak self] in
                let icon = await AppIconCache.shared.loadIcon(forPath: model.appPath)
                guard !Task.isCancelled else { return }
                self?.iconView.image = icon
            }
        }
    }

    func reset() {
        iconLoadTask?.cancel()
        iconLoadTask = nil
        iconView.image = nil
        typeLabel.stringValue = ""
        timestampLabel.stringValue = ""
        backgroundView.layer?.backgroundColor = nil
    }
}

// MARK: - Private

private extension CardHeadView {
    func setup() {
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.backgroundColor = .clear

        addSubview(backgroundView)
        backgroundView.addSubview(textStack)
        backgroundView.addSubview(iconView)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        iconView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(15)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Const.iconSize)
        }

        textStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Const.space10)
            make.trailing.lessThanOrEqualTo(iconView.snp.leading).offset(-Const.space8)
            make.centerY.equalToSuperview()
        }
    }
}
