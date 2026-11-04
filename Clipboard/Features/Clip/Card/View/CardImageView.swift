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
            var fullRect: CGRect?
            while start < text.endIndex,
                  let range = text.range(
                      of: liveTextKeyword, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                      range: start..<text.endIndex
                  ) {
                // 整段外框仅在首次命中时取一次
                let full = fullRect ?? element.accessibilityFrame(for: NSRange(location: 0, length: text.utf16.count))
                fullRect = full
                // 原生辅助功能接口返回屏幕坐标，转换为图片坐标后沿用黄色绘制
                let screenRect = narrowedRect(
                    element.accessibilityFrame(for: NSRange(range, in: text)),
                    for: range, in: text, fullRect: full, element: element
                )
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

    /// 辅助功能接口可能按整行或整词返回外框，此时按字符比例收窄到命中范围；
    /// 接口已返回精确外框时保持原样
    /// - Parameter fullRect: 整段文字的外框，同一元素内只取一次并复用
    private func narrowedRect(
        _ rect: CGRect, for range: Range<String.Index>, in text: String,
        fullRect: CGRect, element: any NSAccessibilityProtocol
    ) -> CGRect {
        guard rect.width > 0, range != text.startIndex..<text.endIndex else { return rect }

        func narrowed(within base: Range<String.Index>) -> CGRect {
            let utf16 = text.utf16
            let total = utf16.distance(from: base.lowerBound, to: base.upperBound)
            guard total > 0 else { return rect }
            let lead = utf16.distance(from: base.lowerBound, to: range.lowerBound)
            let count = utf16.distance(from: range.lowerBound, to: range.upperBound)
            return CGRect(
                x: rect.minX + rect.width * CGFloat(lead) / CGFloat(total),
                y: rect.minY,
                width: rect.width * CGFloat(count) / CGFloat(total),
                height: rect.height
            )
        }

        func matches(_ other: CGRect) -> Bool {
            abs(other.minX - rect.minX) < 1 && abs(other.width - rect.width) < 1
        }

        // 外框与整段文字一致，说明按行返回
        if matches(fullRect) { return narrowed(within: text.startIndex..<text.endIndex) }

        // 否则仅在命中范围所在单词的外框与之一致时，才按词收窄
        var lower = range.lowerBound
        while lower > text.startIndex, !text[text.index(before: lower)].isWhitespace {
            lower = text.index(before: lower)
        }
        var upper = range.upperBound
        while upper < text.endIndex, !text[upper].isWhitespace {
            upper = text.index(after: upper)
        }
        let word = lower..<upper
        guard word != range,
              matches(element.accessibilityFrame(for: NSRange(word, in: text)))
        else { return rect }
        return narrowed(within: word)
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
