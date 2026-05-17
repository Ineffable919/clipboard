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

    private let shareButton = PreviewIconButton(
        systemSymbol: "square.and.arrow.up",
        accessibilityDescription: String(localized: .share)
    )

    private let pinButton = PinChipButton()

    private lazy var rightStack: NSStackView = {
        let stack = NSStackView(views: [pinButton, shareButton, editButton, openWithButton])
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

// MARK: - PinChipButton

private final class PinChipButton: NSView {
    var onPinToChip: ((Int) -> Void)?
    var onUnpin: (() -> Void)?
    var onCreateChip: (() -> Void)?

    private var currentGroup: Int = -1

    private let circleView = PinCircleView()
    private let chevron: NSImageView = {
        let iv = NSImageView()
        iv.image = NSImage(
            systemSymbolName: "chevron.down",
            accessibilityDescription: String(localized: .pin)
        )?.withSymbolConfiguration(.init(pointSize: 8, weight: .medium))
        iv.contentTintColor = .controlTextColor
        return iv
    }()

    private let backgroundLayer = CALayer()
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private func setup() {
        wantsLayer = true

        backgroundLayer.cornerRadius = Const.btnRadius
        backgroundLayer.cornerCurve = .continuous
        layer?.cornerRadius = Const.btnRadius
        layer?.cornerCurve = .continuous
        layer?.insertSublayer(backgroundLayer, at: 0)

        addSubview(circleView)
        addSubview(chevron)

        snp.makeConstraints { make in
            make.height.equalTo(24)
        }

        circleView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Const.space8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }

        chevron.snp.makeConstraints { make in
            make.leading.equalTo(circleView.snp.trailing).offset(4)
            make.trailing.equalToSuperview().inset(Const.space8)
            make.centerY.equalToSuperview()
            make.width.equalTo(10)
            make.height.equalTo(8)
        }

        updateAppearance(animated: false)
    }

    func configure(group: Int) {
        currentGroup = group
        if group == -1 {
            circleView.pinColor = nil
        } else {
            let chip = CategoryChipStore.shared.chips.first { $0.id == group }
            circleView.pinColor = chip.map {
                CategoryChip.paletteNSColors[
                    min(max($0.colorIndex, 0), CategoryChip.paletteNSColors.count - 1)
                ]
            }
        }
    }

    // MARK: - Appearance

    private func updateAppearance(animated: Bool) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let bgColor: NSColor = isHovering
            ? (isDark ? .white.withAlphaComponent(0.08) : .black.withAlphaComponent(0.06))
            : .clear

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                ctx.allowsImplicitAnimation = true
                backgroundLayer.backgroundColor = bgColor.cgColor
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            backgroundLayer.backgroundColor = bgColor.cgColor
            CATransaction.commit()
        }
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance(animated: false)
    }

    // MARK: - Tracking

    override var acceptsFirstResponder: Bool {
        false
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = trackingArea { removeTrackingArea(old) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with _: NSEvent) {
        isHovering = true
        updateAppearance(animated: true)
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with _: NSEvent) {
        isHovering = false
        updateAppearance(animated: true)
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let pressedColor: NSColor = isDark
            ? .white.withAlphaComponent(0.14)
            : .black.withAlphaComponent(0.10)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer.backgroundColor = pressedColor.cgColor
        CATransaction.commit()
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        updateAppearance(animated: false)
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            showMenu(with: event)
        }
        super.mouseUp(with: event)
    }

    private func showMenu(with event: NSEvent) {
        let menu = NSMenu()
        let userChips = CategoryChipStore.shared.chips.filter { !$0.isSystem }
        for chip in userChips {
            let item = NSMenuItem(title: chip.name, action: #selector(handleChipItem(_:)), keyEquivalent: "")
            item.target = self
            item.tag = chip.id
            item.state = currentGroup == chip.id ? .on : .off
            item.image = chipDotImage(colorIndex: chip.colorIndex)
            menu.addItem(item)
        }

        let createItem = NSMenuItem(
            title: String(localized: .createTag),
            action: #selector(handleCreateChip),
            keyEquivalent: ""
        )
        createItem.target = self

        if userChips.isEmpty {
            menu.addItem(createItem)
        } else {
            menu.addItem(.separator())
            if currentGroup != -1 {
                let unpin = NSMenuItem(
                    title: String(localized: .unpin),
                    action: #selector(handleUnpin),
                    keyEquivalent: ""
                )
                unpin.target = self
                menu.addItem(unpin)
            }
            menu.addItem(createItem)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func chipDotImage(colorIndex: Int) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            let color = CategoryChip.paletteNSColors[
                min(max(colorIndex, 0), CategoryChip.paletteNSColors.count - 1)
            ]
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    @objc private func handleChipItem(_ sender: NSMenuItem) {
        guard currentGroup != sender.tag else { return }
        onPinToChip?(sender.tag)
    }

    @objc private func handleUnpin() {
        onUnpin?()
    }

    @objc private func handleCreateChip() {
        onCreateChip?()
    }
}

// MARK: - PinCircleView

private final class PinCircleView: NSView {
    var pinColor: NSColor? {
        didSet { needsDisplay = true }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(ovalIn: rect)

        if let color = pinColor {
            color.setFill()
            path.fill()
        } else {
            NSColor.controlTextColor.setStroke()
            path.lineWidth = 1.5
            path.setLineDash([2.5, 2], count: 2, phase: 0)
            path.stroke()
        }
    }
}
