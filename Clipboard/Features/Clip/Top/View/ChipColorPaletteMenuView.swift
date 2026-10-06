import AppKit
import SwiftUI
import SnapKit

final class ChipColorPaletteMenuView: NSView {
    private let stack = NSStackView()

    init(currentColorIndex: Int, onColorChange: @escaping (Int) -> Void) {
        super.init(frame: .zero)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4

        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        for (index, color) in CategoryChip.palette.enumerated() {
            let circle = ChipColorCircleView(
                color: NSColor(color),
                isSelected: index == currentColorIndex,
                onTap: { onColorChange(index) }
            )
            stack.addArrangedSubview(circle)
            circle.snp.makeConstraints { make in
                make.width.height.equalTo(24)
            }
        }

        layoutSubtreeIfNeeded()
        frame.size = fittingSize
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}

private final class ChipColorCircleView: NSView {
    private let color: NSColor
    private let isSelected: Bool
    private let onTap: () -> Void
    private var isHovering = false

    init(color: NSColor, isSelected: Bool, onTap: @escaping () -> Void) {
        self.color = color
        self.isSelected = isSelected
        self.onTap = onTap
        super.init(frame: .zero)
        wantsLayer = true

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)

        let click = NSClickGestureRecognizer(
            target: self,
            action: #selector(handleTap)
        )
        addGestureRecognizer(click)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func mouseEntered(with _: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with _: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let isActive = isSelected || isHovering

        if isActive {
            if isSelected {
                let gapPath = NSBezierPath(ovalIn: bounds.insetBy(dx: 1.5, dy: 1.5))
                NSColor.controlBackgroundColor.withAlphaComponent(0.6).setFill()
                gapPath.fill()
            }

            let ringPath = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.75, dy: 0.75))
            NSColor.secondaryLabelColor.withAlphaComponent(0.12).setStroke()
            ringPath.lineWidth = 1.5
            ringPath.stroke()
        }

        CategoryDotRenderer.draw(
            in: bounds.insetBy(dx: 5.0, dy: 5.0),
            color: color
        )
    }

    @objc private func handleTap() {
        onTap()
    }
}
