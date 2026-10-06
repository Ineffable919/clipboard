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
    var onShare: ((NSView) -> Void)?
    var onEdit: (() -> Void)?
    var onOpenWithApp: (() -> Void)?
    var onPinToChip: ((Int) -> Void)?
    var onUnpin: (() -> Void)?
    var onCreateChip: (() -> Void)?
    var onToggleMarkdown: (() -> Void)?

    // MARK: - Subviews

    private let closeButton: NSButton = {
        let btn = NSButton()
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.refusesFirstResponder = true
        btn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: String(localized: .close))
        btn.contentTintColor = .secondaryLabelColor
        return btn
    }()

    private let appIconView: NSImageView = {
        let image = NSImageView()
        image.imageScaling = .scaleProportionallyUpOrDown
        image.isHidden = true
        return image
    }()

    private let appNameLabel: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.textColor = .secondaryLabelColor
        field.lineBreakMode = .byTruncatingTail
        return field
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

    private let shareButton = PreviewIconButton(
        systemSymbol: "square.and.arrow.up",
        accessibilityDescription: String(localized: .share)
    )

    private let markdownToggleButton: PreviewIconButton = {
        let btn = PreviewIconButton(
            systemSymbol: "curlybraces",
            accessibilityDescription: String(localized: .previewViewSource)
        )
        btn.isHidden = true
        return btn
    }()

    private let pinButton = PinChipButton()

    private lazy var rightStack: NSStackView = {
        let stack = NSStackView(views: [markdownToggleButton, pinButton, shareButton, editButton, openWithButton])
        stack.orientation = .horizontal
        stack.spacing = Const.space8
        stack.alignment = .centerY
        return stack
    }()

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        shareButton.toolTip = String(localized: .share)
        shareButton.onAction = { [weak self] in
            guard let self else { return }
            onShare?(shareButton)
        }
        editButton.onAction = { [weak self] in self?.onEdit?() }
        openWithButton.onAction = { [weak self] in self?.onOpenWithApp?() }
        markdownToggleButton.onAction = { [weak self] in self?.onToggleMarkdown?() }
        pinButton.toolTip = String(localized: .pin)
        pinButton.onPinToChip = { [weak self] chipId in self?.onPinToChip?(chipId) }
        pinButton.onUnpin = { [weak self] in self?.onUnpin?() }
        pinButton.onCreateChip = { [weak self] in self?.onCreateChip?() }
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
        addSubview(rightStack)

        closeButton.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }

        appIconView.snp.makeConstraints { make in
            make.leading.equalTo(closeButton.snp.trailing).offset(Const.space6)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        rightStack.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }

        appNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(appIconView.snp.trailing).offset(Const.space4)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(rightStack.snp.leading).offset(-Const.space8)
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
        pinButton.configure(group: model.group)
    }

    /// 配置 markdown 渲染/原文切换按钮的可见性与初始状态
    func updateMarkdownToggle(visible: Bool, isRendered: Bool) {
        markdownToggleButton.isHidden = !visible
        if visible {
            setMarkdownRendered(isRendered)
        }
    }

    /// 根据当前渲染态更新切换按钮的图标与提示
    func setMarkdownRendered(_ isRendered: Bool) {
        if isRendered {
            markdownToggleButton.updateSymbol(
                "curlybraces",
                accessibilityDescription: String(localized: .previewViewSource)
            )
            markdownToggleButton.toolTip = String(localized: .previewViewSource)
        } else {
            markdownToggleButton.updateSymbol(
                "eye",
                accessibilityDescription: String(localized: .previewViewRendered)
            )
            markdownToggleButton.toolTip = String(localized: .previewViewRendered)
        }
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
