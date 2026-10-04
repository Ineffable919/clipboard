//
//  CategoryDotRenderer.swift
//  Clipboard
//

import AppKit

enum CategoryDotRenderer {
    static let diameter: CGFloat = 12
    static let borderWidth: CGFloat = 0.5

    static func configure(
        _ view: NSView,
        colorIndex: Int,
        diameter: CGFloat = CategoryDotRenderer.diameter
    ) {
        view.wantsLayer = true
        view.layer?.cornerRadius = diameter / 2

        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            let color = CategoryChip.nsColor(at: colorIndex)
            view.layer?.backgroundColor = color.cgColor
            view.layer?.borderWidth = borderWidth
            view.layer?.borderColor = borderColor(for: color).cgColor
        }
    }

    static func image(
        colorIndex: Int,
        canvasSize: CGFloat = 14,
        diameter: CGFloat = CategoryDotRenderer.diameter
    ) -> NSImage {
        let size = NSSize(width: canvasSize, height: canvasSize)
        let image = NSImage(size: size, flipped: false) { rect in
            let origin = (canvasSize - diameter) / 2
            let dotRect = NSRect(
                x: rect.minX + origin,
                y: rect.minY + origin,
                width: diameter,
                height: diameter
            )
            draw(in: dotRect, colorIndex: colorIndex)
            return true
        }
        image.isTemplate = false
        return image
    }

    static func draw(in rect: NSRect, colorIndex: Int) {
        draw(in: rect, color: CategoryChip.nsColor(at: colorIndex))
    }

    static func draw(in rect: NSRect, color: NSColor) {
        let path = NSBezierPath(ovalIn: rect.insetBy(
            dx: borderWidth / 2,
            dy: borderWidth / 2
        ))
        color.setFill()
        path.fill()

        borderColor(for: color).setStroke()
        path.lineWidth = borderWidth
        path.stroke()
    }

    private static func borderColor(for color: NSColor) -> NSColor {
        color.shadow(withLevel: 0.18) ?? color
    }
}
