import AppKit

// MARK: - Bounded layout

extension JSONViewportEditor {
    func rebuildProjection() {
        displayBlocks = []
        for block in blocks {
            let start = folds.displayLocation(for: block.range.location)
            let end = folds.displayLocation(for: NSMaxRange(block.range))
            guard end > start || source.length == 0 else { continue }
            let range = NSRange(location: start, length: end - start)
            if range.length == block.range.length {
                displayBlocks.append(.init(range: range, widths: block.widths))
            } else {
                let text = displayText(range) as NSString
                for part in JSONViewportIndex.build(text).blocks {
                    displayBlocks.append(.init(
                        range: NSRange(location: start + part.range.location, length: part.range.length),
                        widths: part.widths
                    ))
                }
            }
        }
        rebuildHeights()
        pageBlocks = 0..<0
    }

    func rebuildHeights() {
        let columns = max(12, Int((pageWidth - 30) / 7.83))
        heights = displayBlocks.map { CGFloat($0.rows(columns: columns)) * lineHeight }
        updateOffsets()
    }

    func updateOffsets() {
        offsets = [0]
        for height in heights { offsets.append((offsets.last ?? 0) + max(lineHeight, height)) }
        surface.setFrameSize(NSSize(
            width: pageWidth, height: max(scrollView.contentSize.height, (offsets.last ?? 0) + 16)
        ))
    }

    func block(at height: CGFloat) -> Int {
        var lower = 0
        var upper = heights.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if offsets[middle + 1] <= height { lower = middle + 1 } else { upper = middle }
        }
        return min(max(0, heights.count - 1), lower)
    }

    func block(containing location: Int) -> Int {
        var lower = 0
        var upper = displayBlocks.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if NSMaxRange(displayBlocks[middle].range) <= location { lower = middle + 1 } else { upper = middle }
        }
        return min(max(0, displayBlocks.count - 1), lower)
    }

    func displayText(_ range: NSRange) -> String {
        folds.text(in: source, range: folds.sourceRange(for: range))
    }

    func renderPage() {
        guard !isRendering, !textView.isHandlingInput, !displayBlocks.isEmpty else { return }
        let viewport = scrollView.contentView.bounds
        let center = block(at: viewport.midY)
        let wanted = max(0, center - 1)..<min(displayBlocks.count, center + 2)
        if wanted == pageBlocks {
            ruler.refreshVisibleLines()
            return
        }
        // 输入法组合期间保持当前分页及 marked range
        guard !textView.hasMarkedText() else { return }
        isRendering = true
        suppressChanges = true
        defer { suppressChanges = false; isRendering = false }
        highlightTask?.cancel()
        pageBlocks = wanted
        let start = displayBlocks[wanted.lowerBound].range.location
        let end = NSMaxRange(displayBlocks[wanted.upperBound - 1].range)
        page = NSRange(location: start, length: end - start)
        pageText = displayText(page)
        if let richContent {
            textView.textStorage?.setAttributedString(richContent.attributedSubstring(from: page))
        } else {
            textView.string = pageText
            textView.textStorage?.setAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ], range: NSRange(location: 0, length: (textView.string as NSString).length))
        }
        textView.setFrameSize(NSSize(width: pageWidth, height: 1))
        textView.textContainer?.containerSize = NSSize(
            width: max(100, pageWidth - 20), height: .greatestFiniteMagnitude
        )
        textView.sizeToFit()
        measurePage(anchor: viewport.minY)
        textView.setFrameOrigin(NSPoint(x: 0, y: offsets[wanted.lowerBound]))
        restoreVisibleSelection()
        ruler.refreshVisibleLines()
        scheduleHighlight()
    }

    func measurePage(anchor: CGFloat) {
        guard let layout = textView.layoutManager, let container = textView.textContainer else { return }
        let anchorBlock = block(at: anchor)
        let progress = min(1, max(0, (anchor - offsets[anchorBlock]) / heights[anchorBlock]))
        let length = (textView.string as NSString).length
        guard length > 0 else { return }
        layout.ensureLayout(for: container)
        for index in pageBlocks {
            let start = displayBlocks[index].range.location - page.location
            let end = NSMaxRange(displayBlocks[index].range) - page.location
            let first = layout.glyphIndexForCharacter(at: min(start, length - 1))
            let firstY = layout.lineFragmentRect(forGlyphAt: first, effectiveRange: nil).minY
            let lastY: CGFloat
            if end < length {
                let next = layout.glyphIndexForCharacter(at: end)
                lastY = layout.lineFragmentRect(forGlyphAt: next, effectiveRange: nil).minY
            } else {
                lastY = layout.usedRect(for: container).maxY
            }
            heights[index] = max(lineHeight, lastY - firstY)
        }
        updateOffsets()
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: offsets[anchorBlock] + progress * heights[anchorBlock]))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func restoreVisibleSelection() {
        let display = folds.displayRange(for: selection)
        let start = min(NSMaxRange(page), max(page.location, display.location))
        let end = min(NSMaxRange(page), max(start, NSMaxRange(display)))
        textView.setSelectedRange(NSRange(location: start - page.location, length: end - start))
    }

    @objc func didScroll() { renderPage() }

    func scrollAnchor() -> (location: Int, offset: CGFloat) {
        let location = locationAtTop()
        let length = (textView.string as NSString).length
        guard length > 0, let layout = textView.layoutManager else { return (0, 8) }
        let character = min(length - 1, max(0, location - page.location))
        let glyph = layout.glyphIndexForCharacter(at: character)
        let rect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let offset = textView.frame.minY + textView.textContainerOrigin.y + rect.minY
            - scrollView.contentView.bounds.minY
        return (folds.sourceLocation(for: location), offset)
    }

    func restoreScrollAnchor(_ anchor: (location: Int, offset: CGFloat)) {
        scroll(to: min(source.length, anchor.location))
        let clip = scrollView.contentView
        let origin = NSPoint(x: 0, y: clip.bounds.minY + textView.textContainerOrigin.y - anchor.offset)
        clip.scroll(to: clip.constrainBoundsRect(NSRect(origin: origin, size: clip.bounds.size)).origin)
        scrollView.reflectScrolledClipView(clip)
    }

    func locationAtTop() -> Int {
        guard !displayBlocks.isEmpty else { return 0 }
        if !pageBlocks.isEmpty {
            let top = scrollView.contentView.bounds.minY - textView.frame.minY
            if top >= 0, top < textView.bounds.height {
                let location = textView.characterIndexForInsertion(at: NSPoint(x: 10, y: top + 8))
                return page.location + location
            }
        }
        let index = block(at: scrollView.contentView.bounds.minY)
        return displayBlocks[index].range.location
    }

    func scroll(to sourceLocation: Int) {
        guard !displayBlocks.isEmpty else { return }
        let index = block(containing: folds.displayLocation(for: sourceLocation))
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: offsets[index]))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        renderPage()
        let location = folds.displayLocation(for: sourceLocation) - page.location
        if location >= 0, location < (textView.string as NSString).length,
           let layout = textView.layoutManager {
            let glyph = layout.glyphIndexForCharacter(at: location)
            let rect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: textView.frame.minY + rect.minY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    func toggleFold(_ node: Int) {
        let anchor = scrollAnchor()
        folds.toggle(node)
        rebuildProjection()
        restoreScrollAnchor(anchor)
        updateCursor()
    }

    func scheduleHighlight() {
        guard richContent == nil else { return }
        let text = textView.string
        let revision = revision
        highlightTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .utility) { JSONSyntaxHighlighter.spans(in: text, offset: 0) }
            let spans = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            guard let self, !Task.isCancelled, revision == self.revision,
                  let layout = textView.layoutManager else { return }
            let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let colors: [JSONSyntaxHighlighter.Kind: NSColor] = [
                .string: NSColor(hex: dark ? "#7ECF87" : "#008000"),
                .number: NSColor(hex: dark ? "#8FA8FF" : "#3322FF"),
                .literal: NSColor(hex: dark ? "#D99BE5" : "#B333B3")
            ]
            for span in spans {
                if let color = colors[span.kind] {
                    layout.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: span.range)
                }
            }
        }
    }
}
