//
//  JSONLineNumberRulerView.swift
//  Clipboard
//

import AppKit

final class JSONLineNumberRulerView: NSView {
    var sourceLocation: ((Int) -> Int)?
    var foldAtLine: ((Int) -> (node: Int, collapsed: Bool)?)?
    var onToggleFold: ((Int) -> Void)?

    private struct Line {
        let number: Int
        let rect: NSRect
        let fold: (node: Int, collapsed: Bool)?
    }

    private weak var textView: NSTextView?
    private let lineIndex: JSONLineIndex
    private var currentLine = 1
    private var thickness: CGFloat = 56
    private var visibleLines: [Line] = []
    private var foldElements: [Int: JSONFoldAccessibilityElement] = [:]

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: thickness, height: NSView.noIntrinsicMetric)
    }

    init(textView: NSTextView, lineIndex: JSONLineIndex) {
        self.textView = textView
        self.lineIndex = lineIndex
        super.init(frame: .zero)
        updateThickness()
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError()
    }

    func update(lineCount: Int, currentLine: Int) {
        self.currentLine = currentLine
        updateThickness(lineCount: lineCount)
        needsDisplay = true
    }

    func setTextView(_ textView: NSTextView) {
        self.textView = textView
        clearVisibleLines()
    }

    func clearVisibleLines() {
        visibleLines.removeAll(keepingCapacity: true)
        foldElements.removeAll()
        setAccessibilityChildren([])
        needsDisplay = true
    }

    func refreshVisibleLines() {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return }

        let origin = textView.textContainerOrigin
        let visibleRect = textView.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        layoutManager.ensureLayout(
            forBoundingRect: visibleRect,
            in: textContainer
        )
        let glyphRange = layoutManager.glyphRange(
            forBoundingRect: visibleRect,
            in: textContainer
        )
        var snapshot: [Line] = []

        layoutManager.enumerateLineFragments(
            forGlyphRange: glyphRange
        ) { [weak self] lineRect, _, _, lineGlyphRange, _ in
            guard let self else { return }
            let characterRange = layoutManager.characterRange(
                forGlyphRange: lineGlyphRange,
                actualGlyphRange: nil
            )
            let location = sourceLocation?(characterRange.location) ?? characterRange.location
            guard lineIndex.isLineStart(location) else { return }

            let line = lineIndex.lineNumber(at: location)
            let point = textView.convert(
                NSPoint(x: 0, y: lineRect.minY + origin.y),
                to: self
            )
            snapshot.append(Line(
                number: line,
                rect: NSRect(
                    x: 4,
                    y: point.y,
                    width: bounds.width - 32,
                    height: lineRect.height
                ),
                fold: foldAtLine?(location)
            ))
        }

        visibleLines = snapshot
        updateAccessibility()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()

        NSColor.separatorColor.setFill()
        NSRect(
            x: bounds.maxX - 1,
            y: dirtyRect.minY,
            width: 1,
            height: dirtyRect.height
        ).fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor,
            .paragraphStyle: paragraph
        ]
        let currentAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.controlAccentColor,
            .paragraphStyle: paragraph
        ]

        for line in visibleLines where line.rect.intersects(dirtyRect) {
            String(line.number).draw(
                in: line.rect,
                withAttributes: line.number == currentLine
                    ? currentAttributes
                    : attributes
            )
            if let fold = line.fold {
                drawFold(collapsed: fold.collapsed, in: line.rect)
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        refreshVisibleLines()
        let point = convert(event.locationInWindow, from: nil)
        guard point.x >= bounds.width - 24,
              let line = visibleLines.first(where: { point.y >= $0.rect.minY && point.y < $0.rect.maxY }),
              let fold = line.fold else {
            super.mouseDown(with: event)
            return
        }
        onToggleFold?(fold.node)
    }

    private func drawFold(collapsed: Bool, in rect: NSRect) {
        let center = NSPoint(x: bounds.width - 13, y: rect.midY)
        let path = NSBezierPath()
        path.lineWidth = 1.3
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        if collapsed {
            path.move(to: NSPoint(x: center.x - 2, y: center.y - 4))
            path.line(to: NSPoint(x: center.x + 2, y: center.y))
            path.line(to: NSPoint(x: center.x - 2, y: center.y + 4))
        } else {
            path.move(to: NSPoint(x: center.x - 4, y: center.y - 2))
            path.line(to: NSPoint(x: center.x, y: center.y + 2))
            path.line(to: NSPoint(x: center.x + 4, y: center.y - 2))
        }
        NSColor.secondaryLabelColor.setStroke()
        path.stroke()
    }

    private func updateAccessibility() {
        guard let window else { return }
        var elements: [Int: JSONFoldAccessibilityElement] = [:]
        var children: [JSONFoldAccessibilityElement] = []
        for line in visibleLines where line.rect.intersects(bounds) {
            guard let fold = line.fold else { continue }
            let element = foldElements[fold.node] ?? JSONFoldAccessibilityElement()
            element.setAccessibilityRole(.button)
            element.setAccessibilityEnabled(true)
            element.setAccessibilityParent(self)
            element.setAccessibilityLabel(fold.collapsed
                ? String(localized: .jsonExpandLine(line.number))
                : String(localized: .jsonCollapseLine(line.number)))
            let rect = NSRect(x: bounds.width - 24, y: line.rect.minY, width: 24, height: line.rect.height)
            element.setAccessibilityFrame(window.convertToScreen(convert(rect, to: nil)))
            element.onPress = { [weak self] in self?.onToggleFold?(fold.node) }
            elements[fold.node] = element
            children.append(element)
        }
        foldElements = elements
        setAccessibilityChildren(children)
    }

    private func updateThickness(lineCount: Int? = nil) {
        let count = lineCount ?? lineIndex.lineCount
        let digits = max(2, String(max(1, count)).count)
        let newThickness = max(56, CGFloat(digits * 8 + 36))
        guard newThickness != thickness else { return }
        thickness = newThickness
        invalidateIntrinsicContentSize()
    }
}
