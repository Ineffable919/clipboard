import AppKit
import QuartzCore

/// 静态卡片内容只在数据、尺寸或显示环境变化时绘制，滚动复用完整位图
class CardRasterView: NSView {
    private let imageLayer = CALayer()
    private var contentsDirty = true
    private var renderedSize = NSSize.zero
    private var renderedScale: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // 使用自管图层，避免 AppKit 因滚动可见区域变化维护文字 backing layer
        layer = CALayer()
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        // 根层留给 AppKit 管理可见区域，独立子层保持完整位图的采样范围
        layer?.addSublayer(imageLayer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override var isFlipped: Bool { true }

    override func hitTest(_: NSPoint) -> NSView? { nil }

    func invalidateContents() {
        contentsDirty = true
        needsLayout = true
    }

    func drawContents(in _: NSRect) {}

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor ?? 2
        guard bounds.width > 0, bounds.height > 0,
              contentsDirty || renderedSize != bounds.size || renderedScale != scale
        else { return }

        let width = Int(ceil(bounds.width * scale))
        let height = Int(ceil(bounds.height * scale))
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            drawContents(in: NSRect(origin: .zero, size: bounds.size))
        }
        NSGraphicsContext.restoreGraphicsState()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = NSRect(origin: .zero, size: bounds.size)
        imageLayer.contentsScale = scale
        imageLayer.contents = context.makeImage()
        CATransaction.commit()
        renderedSize = bounds.size
        renderedScale = scale
        contentsDirty = false
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = frame.size != newSize
        super.setFrameSize(newSize)
        if changed { invalidateContents() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        invalidateContents()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        invalidateContents()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        invalidateContents()
    }
}
