//
//  ClipDropOverlayView.swift
//  Clipboard
//
//  Created by Crown on 2026/6/1.
//

import AppKit
import SnapKit

final class ClipDropOverlayView: NSView {
    var canAcceptDrag: ((any NSDraggingInfo) -> Bool)?
    var acceptDrag: ((any NSDraggingInfo) -> Bool)?

    private let dimmingView = NSView()
    private let dropZoneView = DropZoneView()
    private let contentStack = NSStackView()
    private let illustrationView = DropIllustrationView()
    private let titleLabel = NSTextField(labelWithString: String(localized: .dropOverlayTitle))
    private let subtitleLabel = NSTextField(labelWithString: String(localized: .dropOverlaySubtitle))

    private var isOverlayVisible = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        setupConstraints()
        registerForDraggedTypes(PasteboardType.supportTypes)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func setOverlayVisible(_ visible: Bool) {
        guard isOverlayVisible != visible else { return }
        isOverlayVisible = visible

        NSAnimationContext.runAnimationGroup { context in
            context.duration = visible ? 0.16 : 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = visible ? 1.0 : 0.0
        }
    }

    func resetDragState() {
        setOverlayVisible(false)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        validate(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        validate(sender)
    }

    override func draggingExited(_: (any NSDraggingInfo)?) {
        resetDragState()
    }

    override func draggingEnded(_: any NSDraggingInfo) {
        resetDragState()
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        canAcceptDrag?(sender) == true
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let accepted = acceptDrag?(sender) == true
        resetDragState()
        return accepted
    }

    func concludeDragOperation(_: any NSDraggingInfo) {
        resetDragState()
    }

    private func validate(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard canAcceptDrag?(sender) == true else {
            resetDragState()
            return []
        }
        setOverlayVisible(true)
        return .copy
    }

    private func setupView() {
        wantsLayer = true
        alphaValue = 0.0

        dimmingView.wantsLayer = true

        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.maximumNumberOfLines = 1

        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 2

        contentStack.orientation = .vertical
        contentStack.alignment = .centerX
        contentStack.spacing = Const.space8
        contentStack.addArrangedSubview(illustrationView)
        contentStack.setCustomSpacing(Const.space12, after: illustrationView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)

        addSubview(dimmingView)
        addSubview(dropZoneView)
        addSubview(contentStack)
        updateColors()
    }

    private func updateColors() {
        dimmingView.layer?.backgroundColor = NSColor.windowBackgroundColor
            .withAlphaComponent(0.78)
            .cgColor
        titleLabel.textColor = .labelColor
        subtitleLabel.textColor = .secondaryLabelColor
        dropZoneView.updateColors()
        illustrationView.updateColors()
    }

    private func setupConstraints() {
        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        dropZoneView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Const.space20)
            make.top.bottom.equalToSuperview().inset(Const.space2)
        }

        illustrationView.snp.makeConstraints { make in
            make.width.equalTo(154)
            make.height.equalTo(112)
        }

        titleLabel.snp.makeConstraints { make in
            make.width.lessThanOrEqualToSuperview()
        }

        subtitleLabel.snp.makeConstraints { make in
            make.width.lessThanOrEqualToSuperview()
        }

        contentStack.snp.makeConstraints { make in
            make.center.equalTo(dropZoneView)
            make.leading.greaterThanOrEqualTo(dropZoneView).offset(Const.space20)
            make.trailing.lessThanOrEqualTo(dropZoneView).offset(-Const.space20)
        }
    }
}

private final class DropZoneView: NSView {
    private let fillLayer = CALayer()
    private let borderLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateLayers()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func updateColors() {
        fillLayer.backgroundColor = NSColor.controlBackgroundColor
            .withAlphaComponent(0.86)
            .cgColor
        fillLayer.shadowColor = NSColor.controlAccentColor.cgColor
        borderLayer.strokeColor = NSColor.controlAccentColor
            .withAlphaComponent(0.86)
            .cgColor
    }

    private func setupLayers() {
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.addSublayer(fillLayer)
        layer?.addSublayer(borderLayer)

        fillLayer.shadowOpacity = 0.10
        fillLayer.shadowRadius = 24
        fillLayer.shadowOffset = CGSize(width: 0, height: 8)

        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.lineWidth = 2
        borderLayer.lineDashPattern = [8, 7]
        updateColors()
    }

    private func updateLayers() {
        let radius: CGFloat = 18
        fillLayer.frame = bounds
        fillLayer.cornerRadius = radius
        fillLayer.cornerCurve = .continuous

        let borderRect = bounds.insetBy(dx: 1, dy: 1)
        borderLayer.frame = bounds
        borderLayer.path = CGPath(
            roundedRect: borderRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
    }
}

private final class DropIllustrationView: NSView {
    private let glowView = NSView()
    private let folderView = DropFolderView()
    private let arrowImageView = NSImageView()
    private let imageBadge = FloatingBadgeView(symbolName: "photo", rotation: 45, prominence: .medium)
    private let documentBadge = FloatingBadgeView(symbolName: "doc.text", rotation: 0, prominence: .medium)
    private let textBadge = FloatingBadgeView(symbolName: "t.square", rotation: -45, prominence: .medium)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func updateColors() {
        glowView.layer?.backgroundColor = NSColor.controlAccentColor
            .withAlphaComponent(0.14)
            .cgColor
        glowView.layer?.shadowColor = NSColor.controlAccentColor.cgColor
        folderView.needsDisplay = true
        imageBadge.updateColors()
        documentBadge.updateColors()
        textBadge.updateColors()
    }

    private func setupView() {
        wantsLayer = true

        glowView.wantsLayer = true
        glowView.layer?.cornerRadius = 28
        glowView.layer?.cornerCurve = .continuous
        glowView.layer?.shadowOpacity = 0.16
        glowView.layer?.shadowRadius = 18
        glowView.layer?.shadowOffset = .zero

        let arrowConfig = NSImage.SymbolConfiguration(pointSize: 22, weight: .bold)
        arrowImageView.image = NSImage(systemSymbolName: "arrow.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(arrowConfig)
        arrowImageView.contentTintColor = .white
        arrowImageView.imageScaling = .scaleProportionallyUpOrDown

        addSubview(glowView)
        addSubview(imageBadge)
        addSubview(documentBadge)
        addSubview(textBadge)
        addSubview(folderView)
        addSubview(arrowImageView)
        updateColors()
    }

    private func setupConstraints() {
        glowView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-3)
            make.width.equalTo(86)
            make.height.equalTo(58)
        }

        folderView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
            make.width.equalTo(90)
            make.height.equalTo(66)
        }

        arrowImageView.snp.makeConstraints { make in
            make.centerX.equalTo(folderView)
            make.centerY.equalTo(folderView).offset(10)
            make.width.height.equalTo(26)
        }

        documentBadge.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
            make.width.equalTo(32)
            make.height.equalTo(40)
        }

        imageBadge.snp.makeConstraints { make in
            make.centerX.equalTo(documentBadge).offset(-36)
            make.centerY.equalTo(documentBadge).offset(24)
            make.width.equalTo(32)
            make.height.equalTo(40)
        }

        textBadge.snp.makeConstraints { make in
            make.centerX.equalTo(documentBadge).offset(48)
            make.centerY.equalTo(documentBadge)
            make.width.equalTo(32)
            make.height.equalTo(40)
        }
    }
}

private final class DropFolderView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.shadowColor = NSColor.controlAccentColor.cgColor
        layer?.shadowOpacity = 0.20
        layer?.shadowRadius = 18
        layer?.shadowOffset = CGSize(width: 0, height: 10)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.shadowColor = NSColor.controlAccentColor.cgColor
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let accent = NSColor.controlAccentColor
        let bodyRect = bounds.insetBy(dx: 2, dy: 2)
        let tabY = bodyRect.maxY - bodyRect.height * 0.34
        let radius: CGFloat = 10

        let path = NSBezierPath()
        path.move(to: NSPoint(x: bodyRect.minX + radius, y: bodyRect.minY))
        path.line(to: NSPoint(x: bodyRect.maxX - radius, y: bodyRect.minY))
        path.curve(
            to: NSPoint(x: bodyRect.maxX, y: bodyRect.minY + radius),
            controlPoint1: NSPoint(x: bodyRect.maxX - radius * 0.45, y: bodyRect.minY),
            controlPoint2: NSPoint(x: bodyRect.maxX, y: bodyRect.minY + radius * 0.45)
        )
        path.line(to: NSPoint(x: bodyRect.maxX, y: tabY))
        path.curve(
            to: NSPoint(x: bodyRect.maxX - 9, y: tabY + 8),
            controlPoint1: NSPoint(x: bodyRect.maxX, y: tabY + 5),
            controlPoint2: NSPoint(x: bodyRect.maxX - 3, y: tabY + 8)
        )
        path.line(to: NSPoint(x: bodyRect.midX + 15, y: tabY + 8))
        path.curve(
            to: NSPoint(x: bodyRect.midX + 4, y: tabY),
            controlPoint1: NSPoint(x: bodyRect.midX + 9, y: tabY + 8),
            controlPoint2: NSPoint(x: bodyRect.midX + 10, y: tabY)
        )
        path.line(to: NSPoint(x: bodyRect.minX + 20, y: tabY))
        path.curve(
            to: NSPoint(x: bodyRect.minX, y: tabY - 10),
            controlPoint1: NSPoint(x: bodyRect.minX + 8, y: tabY),
            controlPoint2: NSPoint(x: bodyRect.minX, y: tabY - 4)
        )
        path.line(to: NSPoint(x: bodyRect.minX, y: bodyRect.minY + radius))
        path.curve(
            to: NSPoint(x: bodyRect.minX + radius, y: bodyRect.minY),
            controlPoint1: NSPoint(x: bodyRect.minX, y: bodyRect.minY + radius * 0.45),
            controlPoint2: NSPoint(x: bodyRect.minX + radius * 0.45, y: bodyRect.minY)
        )
        path.close()

        NSGraphicsContext.saveGraphicsState()
        let gradient = NSGradient(colors: [
            accent.withAlphaComponent(0.54),
            accent.withAlphaComponent(0.74)
        ])
        gradient?.draw(in: path, angle: -82)
        NSGraphicsContext.restoreGraphicsState()

        accent.withAlphaComponent(0.16).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

private final class FloatingBadgeView: NSView {
    enum Prominence {
        case soft
        case medium
    }

    private let imageView = NSImageView()
    private let symbolName: String
    private let rotation: CGFloat
    private let prominence: Prominence

    init(symbolName: String, rotation: CGFloat, prominence: Prominence) {
        self.symbolName = symbolName
        self.rotation = rotation
        self.prominence = prominence
        super.init(frame: .zero)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    override func layout() {
        super.layout()
        frameCenterRotation = rotation
    }

    func updateColors() {
        let backgroundAlpha: CGFloat = prominence == .soft ? 0.08 : 0.13
        let symbolAlpha: CGFloat = prominence == .soft ? 0.34 : 0.68
        layer?.backgroundColor = NSColor.controlAccentColor
            .withAlphaComponent(backgroundAlpha)
            .cgColor
        imageView.contentTintColor = NSColor.controlAccentColor.withAlphaComponent(symbolAlpha)
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.shadowColor = NSColor.controlAccentColor.cgColor
        layer?.shadowOpacity = prominence == .soft ? 0.04 : 0.08
        layer?.shadowRadius = prominence == .soft ? 8 : 11
        layer?.shadowOffset = CGSize(width: 0, height: 4)

        let config = NSImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)
        updateColors()
    }

    private func setupConstraints() {
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(26)
        }
    }
}
