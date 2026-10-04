import AppKit
import SnapKit

final class DropIllustrationView: NSView {
    private let glowView = NSView()
    private let folderView = DropFolderView()
    private let arrowImageView = NSImageView()
    private let imageBadge = FloatingBadgeView(symbolName: "photo", rotation: 25, prominence: .medium)
    private let documentBadge = FloatingBadgeView(symbolName: "doc.text", rotation: 0, prominence: .medium)
    private let textBadge = FloatingBadgeView(symbolName: "t.square", rotation: -25, prominence: .medium)

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
        effectiveAppearance.performAsCurrentDrawingAppearance {
            glowView.layer?.backgroundColor = NSColor.controlAccentColor
                .withAlphaComponent(0.14)
                .cgColor
            glowView.layer?.shadowColor = NSColor.controlAccentColor.cgColor
        }
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
            make.width.equalTo(88)
            make.height.equalTo(64)
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

        let radius: CGFloat = 75
        let sideOffset: CGFloat = 45
        let sideHeight = (radius * radius - sideOffset * sideOffset).squareRoot()

        documentBadge.snp.makeConstraints { make in
            make.centerX.equalTo(folderView)
            make.centerY.equalTo(folderView).offset(-radius)
            make.width.equalTo(32)
            make.height.equalTo(40)
        }

        imageBadge.snp.makeConstraints { make in
            make.centerX.equalTo(folderView).offset(-sideOffset)
            make.centerY.equalTo(folderView).offset(-sideHeight)
            make.width.equalTo(32)
            make.height.equalTo(40)
        }

        textBadge.snp.makeConstraints { make in
            make.centerX.equalTo(folderView).offset(sideOffset)
            make.centerY.equalTo(folderView).offset(-sideHeight)
            make.width.equalTo(32)
            make.height.equalTo(40)
        }
    }
}

private final class DropFolderView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.shadowColor = NSColor.controlAccentColor.cgColor
        }
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
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.shadowColor = NSColor.controlAccentColor.cgColor
        }
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

    override var wantsUpdateLayer: Bool {
        true
    }

    override func updateLayer() {
        let backgroundAlpha: CGFloat = prominence == .soft ? 0.08 : 0.13
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlAccentColor
                .withAlphaComponent(backgroundAlpha)
                .cgColor
        }
        guard bounds.size != .zero else { return }
        let midX = bounds.midX, midY = bounds.midY
        let angle = rotation * .pi / 180
        var transform = CATransform3DTranslate(CATransform3DIdentity, midX, midY, 0)
        transform = CATransform3DRotate(transform, angle, 0, 0, 1)
        transform = CATransform3DTranslate(transform, -midX, -midY, 0)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.transform = transform
        CATransaction.commit()
    }

    func updateColors() {
        let symbolAlpha: CGFloat = prominence == .soft ? 0.34 : 0.68
        imageView.contentTintColor = NSColor.controlAccentColor.withAlphaComponent(symbolAlpha)
        needsDisplay = true
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
