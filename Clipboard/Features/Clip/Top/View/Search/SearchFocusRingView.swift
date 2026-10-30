import AppKit

final class SearchFocusRingView: NSView {
    static let inset: CGFloat = 8
    var cornerRadius: CGFloat = 0 {
        didSet {
            if cornerRadius != oldValue { needsDisplay = true }
        }
    }

    override func hitTest(_: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: Self.inset, dy: Self.inset)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSFocusRingPlacement.only.set()
        NSColor.white.setFill()
        NSBezierPath(
            roundedRect: rect,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        ).fill()
    }
}
