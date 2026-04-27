//
//  PreviewHeaderBar.swift
//  Clipboard
//
//  预览顶部栏
//

import AppKit
import SnapKit

// MARK: - PreviewHeaderBar

final class PreviewHeaderBar: NSView {
    // MARK: - Callbacks

    var onClose: (() -> Void)?
    var onEdit: (() -> Void)?
    var onOpenWithApp: (() -> Void)?

    // MARK: - Subviews

    private let closeButton: NSButton = {
        let btn = NSButton()
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.refusesFirstResponder = true
        btn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
        btn.contentTintColor = .secondaryLabelColor
        return btn
    }()

    private let appIconView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.isHidden = true
        return iv
    }()

    private let appNameLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: NSFont.systemFontSize)
        f.textColor = .secondaryLabelColor
        f.lineBreakMode = .byTruncatingTail
        return f
    }()

    private let editButton: PreviewPillButton = {
        let btn = PreviewPillButton(title: String(localized: .edit))
        btn.isHidden = true
        return btn
    }()

    private let openWithButton: PreviewPillButton = {
        let btn = PreviewPillButton()
        btn.isHidden = true
        return btn
    }()

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        editButton.onAction = { [weak self] in self?.onEdit?() }
        openWithButton.onAction = { [weak self] in self?.onOpenWithApp?() }
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Layout

    private func setupLayout() {
        addSubview(closeButton)
        addSubview(appIconView)
        addSubview(appNameLabel)
        addSubview(editButton)
        addSubview(openWithButton)

        closeButton.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }

        appIconView.snp.makeConstraints { make in
            make.leading.equalTo(closeButton.snp.trailing).offset(Const.space6)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        appNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(appIconView.snp.trailing).offset(Const.space4)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(editButton.snp.leading).offset(-Const.space8)
        }

        editButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }

        openWithButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
    }

    // MARK: - Public API

    func configure(model: PasteboardModel, appIcon: NSImage?) {
        appNameLabel.stringValue = model.appName

        if let icon = appIcon {
            appIconView.image = icon
            appIconView.isHidden = false
        } else {
            appIconView.isHidden = true
        }

        editButton.isHidden = !model.pasteboardType.isText()
    }

    func updateOpenWithApp(isSingleFile: Bool, defaultAppForFile: String?) {
        if isSingleFile, let appName = defaultAppForFile {
            openWithButton.title = String(localized: .openWithApp(appName))
            openWithButton.isHidden = false
        } else {
            openWithButton.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        onClose?()
    }
}
