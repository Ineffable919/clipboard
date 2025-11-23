//
//  NSImage+Extension.swift
//  Clip
//
//  Created by crown on 2025/8/14.
//

import AppKit

extension NSImage {
    private static var cachedCheckerboard: NSImage?

    static func checkerboard(
        squareSize: CGFloat = 8,
        light: NSColor = .white,
        dark: NSColor = NSColor(white: 0.9, alpha: 1),
    ) -> NSImage {
        if let cached = cachedCheckerboard {
            return cached
        }

        let size = CGSize(width: squareSize * 2, height: squareSize * 2)
        let image = NSImage(size: size)
        image.lockFocus()

        light.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

        dark.setFill()
        NSBezierPath(
            rect: CGRect(x: 0, y: squareSize, width: squareSize, height: squareSize),
        ).fill()
        NSBezierPath(
            rect: CGRect(x: squareSize, y: 0, width: squareSize, height: squareSize),
        ).fill()

        image.unlockFocus()
        cachedCheckerboard = image
        return image
    }
}
