import AppKit
import SnapKit
import VisionKit

/// 按裁剪比例绘制卡片图片，并在统一图片坐标系中绘制黄色搜索高亮
final class CardImageView: NSView {
    var image: NSImage? {
        didSet {
            needsDisplay = true
            textOverlay?.setContentsRectNeedsUpdate()
        }
    }

    var regions: [OCRTextRegion] = [] {
        didSet { needsDisplay = true }
    }

    private let maxFillCropRatio: CGFloat = 0.15
    private var textOverlay: ImageAnalysisOverlayView?
    private var liveTextKeyword = ""

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
        if changed {
            needsDisplay = true
            textOverlay?.setContentsRectNeedsUpdate()
        }
    }

    func clearHighlights() {
        liveTextKeyword = ""
        regions = []
    }

    @available(macOS 27.0, *)
    func highlight(_ analysis: ImageAnalysis, keyword: String) {
        let overlay: ImageAnalysisOverlayView
        if let textOverlay {
            overlay = textOverlay
        } else {
            overlay = ImageAnalysisOverlayView(frame: bounds)
            overlay.delegate = self
            overlay.preferredInteractionTypes = .textSelection
            overlay.isSupplementaryInterfaceHidden = true
            addSubview(overlay)
            overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
            textOverlay = overlay
        }
        regions = []
        overlay.analysis = analysis
        overlay.setContentsRectNeedsUpdate()
        liveTextKeyword = keyword
        needsDisplay = true
    }

    private func liveTextHighlightRegions() -> [OCRTextRegion] {
        guard !liveTextKeyword.isEmpty, let overlay = textOverlay, let window, let image,
              image.size.width > 0, image.size.height > 0, bounds.width > 0, bounds.height > 0
        else { return [] }
        let rect = imageRect(for: image.size)
        var pending = overlay.accessibilityChildren() ?? []
        var highlights: [OCRTextRegion] = []
        while let child = pending.popLast() {
            guard let element = child as? any NSAccessibilityProtocol else { continue }
            let role = element.accessibilityRole()
            guard role == .textArea || role == .staticText,
                  let text = element.accessibilityValue() as? String
            else {
                pending.append(contentsOf: element.accessibilityChildren() ?? [])
                continue
            }
            var start = text.startIndex
            while start < text.endIndex,
                  let range = text.range(
                      of: liveTextKeyword, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                      range: start..<text.endIndex
                  ) {
                // 原生辅助功能接口返回屏幕坐标，转换为图片坐标后沿用黄色绘制
                let screenRect = element.accessibilityFrame(for: NSRange(range, in: text))
                if !screenRect.isEmpty {
                    let localRect = convert(window.convertFromScreen(screenRect), from: nil)
                    highlights.append(OCRTextRegion(text: String(text[range]), boundingBox: CGRect(
                        x: (localRect.minX - rect.minX) / rect.width,
                        y: 1 - (localRect.maxY - rect.minY) / rect.height,
                        width: localRect.width / rect.width, height: localRect.height / rect.height
                    )))
                }
                start = range.upperBound
            }
        }
        return highlights
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
            in: rect, from: .zero, operation: .sourceOver,
            fraction: 1, respectFlipped: true, hints: nil
        )

        NSColor.systemYellow.withAlphaComponent(0.45).setFill()
        let highlights = liveTextKeyword.isEmpty ? regions : liveTextHighlightRegions()
        for region in highlights {
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
        let scale = cropRatio <= maxFillCropRatio ? fillScale : min(widthScale, heightScale)
        let width = size.width * scale
        let height = size.height * scale

        // 向外取整最终绘制范围，避免二次等比缩放和边缘漏出底色
        return NSRect(
            x: bounds.midX - width / 2, y: bounds.midY - height / 2,
            width: width, height: height
        ).integral
    }
}

extension CardImageView: ImageAnalysisOverlayViewDelegate {
    func contentsRect(for _: ImageAnalysisOverlayView) -> CGRect {
        guard let image, image.size.width > 0, image.size.height > 0,
              bounds.width > 0, bounds.height > 0
        else { return .zero }
        let rect = imageRect(for: image.size)
        return CGRect(
            x: (rect.minX - bounds.minX) / bounds.width,
            y: (rect.minY - bounds.minY) / bounds.height,
            width: rect.width / bounds.width, height: rect.height / bounds.height
        )
    }
}
