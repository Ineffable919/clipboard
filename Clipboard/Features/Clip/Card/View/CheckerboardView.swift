//
//  CheckerboardView.swift
//  Clipboard
//

import AppKit

// MARK: - CheckerboardView

final class CheckerboardView: NSView {
    private var cachedTile: CGImage?
    private var cachedAppearanceName: NSAppearance.Name?
    private var lightColor: NSColor = Const.lightImageShallowColor
    private var darkColor: NSColor = Const.lightImageDeepColor

    private static let tileSize: CGFloat = 16 // 2×2 格，每格 8pt

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let tile = currentTile() else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.saveGState()
        ctx.clip(to: dirtyRect)
        let tileSize = Self.tileSize
        let origin = bounds.origin
        var top = origin.y
        while top < dirtyRect.maxY {
            var left = origin.x
            while left < dirtyRect.maxX {
                ctx.draw(tile, in: CGRect(x: left, y: top, width: tileSize, height: tileSize))
                left += tileSize
            }
            top += tileSize
        }
        ctx.restoreGState()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        cachedAppearanceName = nil
        cachedTile = nil
        needsDisplay = true
    }

    // MARK: Private

    private func currentTile() -> CGImage? {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let name: NSAppearance.Name = isDark ? .darkAqua : .aqua
        if cachedAppearanceName == name, let tile = cachedTile {
            return tile
        }

        cachedAppearanceName = name
        lightColor = isDark ? Const.darkImageShallowColor : Const.lightImageShallowColor
        darkColor = isDark ? Const.darkImageDeepColor : Const.lightImageDeepColor
        cachedTile = renderTile()
        return cachedTile
    }

    private func renderTile() -> CGImage? {
        let size = Int(Self.tileSize)
        let half = size / 2
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: size, height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setFillColor(lightColor.cgColor)
        ctx.fill([CGRect(x: 0, y: 0, width: half, height: half),
                  CGRect(x: half, y: half, width: half, height: half)])

        ctx.setFillColor(darkColor.cgColor)
        ctx.fill([CGRect(x: half, y: 0, width: half, height: half),
                  CGRect(x: 0, y: half, width: half, height: half)])

        return ctx.makeImage()
    }
}
