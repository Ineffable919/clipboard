//
//  CardImageView.swift
//  Clipboard
//
//  Created by crown on 2026/10/29
//

import AppKit

/// 按裁剪比例绘制卡片图片，并在统一图片坐标系中绘制黄色搜索高亮
final class CardImageView: NSView {
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    var regions: [OCRTextRegion] = [] {
        didSet { needsDisplay = true }
    }

    private let maxFillCropRatio: CGFloat = 0.15

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override var isFlipped: Bool { true }

    override func hitTest(_: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = frame.size != newSize
        super.setFrameSize(newSize)
        if changed { needsDisplay = true }
    }

    override func draw(_: NSRect) {
        guard let image, image.size.width > 0, image.size.height > 0,
            bounds.width > 0, bounds.height > 0
        else { return }

        let rect = imageRect(for: image.size)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect: bounds).addClip()
        image.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )

        NSColor.systemYellow.withAlphaComponent(0.45).setFill()
        for region in regions {
            let box = region.boundingBox
            let highlight = NSRect(
                x: rect.minX + box.minX * rect.width,
                y: rect.minY + (1 - box.maxY) * rect.height,
                width: box.width * rect.width,
                height: box.height * rect.height
            )
            NSBezierPath(roundedRect: highlight, xRadius: 2, yRadius: 2).fill()
        }
    }

    private func imageRect(for size: NSSize) -> NSRect {
        let widthScale = bounds.width / size.width
        let heightScale = bounds.height / size.height
        let fillScale = max(widthScale, heightScale)
        let fillArea = size.width * size.height * fillScale * fillScale
        let cropRatio = max(0, 1 - bounds.width * bounds.height / fillArea)
        let scale =
            cropRatio <= maxFillCropRatio
            ? fillScale : min(widthScale, heightScale)
        let width = size.width * scale
        let height = size.height * scale

        // 向外取整最终绘制范围，避免二次等比缩放和边缘漏出底色
        return NSRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        ).integral
    }
}
