//
//  JSONLineNumberRulerView.swift
//  Clipboard
//

import AppKit

final class JSONLineNumberRulerView: NSView {
    private weak var textView: NSTextView?
    private let lineIndex: JSONLineIndex
    private var currentLine = 1
    private var thickness: CGFloat = 36
    private var visibleLines: [(number: Int, rect: NSRect)] = []

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

    func clearVisibleLines() {
        visibleLines.removeAll(keepingCapacity: true)
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
        var snapshot: [(number: Int, rect: NSRect)] = []

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) {
            [weak self] lineRect, _, _, lineGlyphRange, _ in
            guard let self else { return }
            let characterRange = layoutManager.characterRange(
                forGlyphRange: lineGlyphRange,
                actualGlyphRange: nil
            )
            guard lineIndex.isLineStart(characterRange.location) else { return }

            let line = lineIndex.lineNumber(at: characterRange.location)
            let point = textView.convert(
                NSPoint(x: 0, y: lineRect.minY + origin.y),
                to: self
            )
            snapshot.append((
                number: line,
                rect: NSRect(
                    x: 4,
                    y: point.y,
                    width: bounds.width - 10,
                    height: lineRect.height
                )
            ))
        }

        visibleLines = snapshot
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
            .paragraphStyle: paragraph,
        ]
        let currentAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.controlAccentColor,
            .paragraphStyle: paragraph,
        ]

        for line in visibleLines where line.rect.intersects(dirtyRect) {
            String(line.number).draw(
                in: line.rect,
                withAttributes: line.number == currentLine
                    ? currentAttributes
                    : attributes
            )
        }
    }

    private func updateThickness(lineCount: Int? = nil) {
        let count = lineCount ?? lineIndex.lineCount
        let digits = max(2, String(max(1, count)).count)
        let newThickness = max(36, CGFloat(digits * 8 + 16))
        guard newThickness != thickness else { return }
        thickness = newThickness
        invalidateIntrinsicContentSize()
    }
}
