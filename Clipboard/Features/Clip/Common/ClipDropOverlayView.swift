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
    private let subtitleLabel = NSTextField(labelWithString: String(localized: .dropOverlaySub))

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
        effectiveAppearance.performAsCurrentDrawingAppearance {
            dimmingView.layer?.backgroundColor = NSColor.windowBackgroundColor
                .withAlphaComponent(0.78)
                .cgColor
        }
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
            make.edges.equalToSuperview().inset(Const.space2)
        }

        illustrationView.snp.makeConstraints { make in
            make.width.equalTo(154)
            make.height.equalTo(130)
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
        effectiveAppearance.performAsCurrentDrawingAppearance {
            fillLayer.backgroundColor = NSColor.controlBackgroundColor
                .withAlphaComponent(0.86)
                .cgColor
            fillLayer.shadowColor = NSColor.controlAccentColor.cgColor
            borderLayer.strokeColor = NSColor.controlAccentColor
                .withAlphaComponent(0.86)
                .cgColor
        }
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
