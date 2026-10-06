import AppKit

extension JSONEditorView {
    // MARK: - Line Index

    func rebuildLineIndex(for text: String, generation: Int) {
        isLineIndexReady = false
        lineTask?.cancel()
        lineNumberTask?.cancel()
        lineRuler.clearVisibleLines()
        lineTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .utility) {
                JSONLineIndex.build(for: text)
            }
            let starts = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard let self,
                  !Task.isCancelled,
                  generation == self.generation
            else { return }

            lineIndex.replace(with: starts)
            lineIndexRevision &+= 1
            isLineIndexReady = true
            updateCursor()
        }
    }

    func updateLineIndexAfterTextChange() {
        if shouldRebuildLineIndex {
            shouldRebuildLineIndex = false
            rebuildLineIndex(for: textView.string, generation: generation)
            return
        }

        guard isLineIndexReady else {
            rebuildLineIndex(for: textView.string, generation: generation)
            return
        }

        if textView.selectedRange() != reportedSelection
            || lineIndexRevision != reportedLineIndexRevision {
            updateCursor()
        }
    }

    func updateCursor() {
        let selection = textView.selectedRange()
        reportedSelection = selection
        reportedLineIndexRevision = lineIndexRevision
        let location = folds.sourceLocation(for: selection.location)
        let position = lineIndex.lineAndColumn(at: location)
        lineRuler.update(lineCount: lineIndex.lineCount, currentLine: position.line)
        onCursorChange?(position.line, position.column)
        scheduleLineNumberRefresh()
    }

    func scheduleLineNumberRefresh(immediately: Bool = false) {
        guard !isClosed else { return }
        lineNumberTask?.cancel()
        lineNumberTask = Task { @MainActor [weak self] in
            if immediately {
                await Task.yield()
            } else {
                try? await Task.sleep(for: .milliseconds(16))
            }
            guard let self,
                  !Task.isCancelled,
                  isLineIndexReady,
                  !isHidden
            else { return }

            lineRuler.refreshVisibleLines()
        }
    }

    // MARK: - Highlighting

    @objc func handleScroll() {
        guard viewport == nil else { return }
        scheduleHighlight()
        scheduleLineNumberRefresh(immediately: true)
    }

    func cancelHighlight() {
        highlightRequestID &+= 1
        highlightWorkerID &+= 1
        highlightTask?.cancel()
        highlightTask = nil
    }

    func scheduleHighlight() {
        guard !isClosed else { return }
        highlightRequestID &+= 1
        guard highlightTask == nil else { return }

        highlightWorkerID &+= 1
        let workerID = highlightWorkerID
        highlightTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if workerID == highlightWorkerID {
                    highlightTask = nil
                }
            }

            while !Task.isCancelled {
                let requestID = highlightRequestID
                let generation = generation
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
                guard requestID == highlightRequestID,
                      generation == self.generation
                else { continue }
                guard let range = highlightScanRange(),
                      let storage = textView.textStorage else { return }
                let segment = storage.mutableString.substring(with: range)
                let worker = Task.detached(priority: .utility) {
                    JSONSyntaxHighlighter.spans(in: segment, offset: range.location)
                }
                let spans = await withTaskCancellationHandler {
                    await worker.value
                } onCancel: {
                    worker.cancel()
                }

                guard !Task.isCancelled else { return }
                guard requestID == highlightRequestID,
                      generation == self.generation
                else { continue }
                applyHighlight(spans, in: range)
                return
            }
        }
    }

    func applyHighlight(_ spans: [JSONSyntaxHighlighter.Span], in range: NSRange) {
        guard let layoutManager = textView.layoutManager,
              let storage = textView.textStorage else { return }
        let removableRange = NSIntersectionRange(highlightedRange, NSRange(location: 0, length: storage.length))
        if removableRange.length > 0 {
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: removableRange)
        }
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let colors: [JSONSyntaxHighlighter.Kind: NSColor] = [
            .string: isDark ? Self.darkString : Self.lightString,
            .number: isDark ? Self.darkNumber : Self.lightNumber,
            .literal: isDark ? Self.darkLiteral : Self.lightLiteral
        ]
        for span in spans where NSMaxRange(span.range) <= storage.length {
            // 键和标点沿用正文色，避免为每个标点维护临时属性
            guard let color = colors[span.kind] else { continue }
            layoutManager.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: span.range)
        }
        highlightedRange = range
        highlightedGeneration = generation
    }

    func highlightScanRange() -> NSRange? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return nil }

        let textLength = textView.textStorage?.length ?? 0
        guard textLength > 0 else { return nil }

        let origin = textView.textContainerOrigin
        let visibleRect = textView.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let glyphRange = layoutManager.glyphRange(
            forBoundingRect: visibleRect,
            in: textContainer
        )
        let visibleCharacters = layoutManager.characterRange(
            forGlyphRange: glyphRange,
            actualGlyphRange: nil
        )
        if highlightedGeneration == generation,
           NSIntersectionRange(highlightedRange, visibleCharacters) == visibleCharacters {
            return nil
        }
        let lookaround = 32768
        let start = max(0, visibleCharacters.location - lookaround)
        let end = min(textLength, NSMaxRange(visibleCharacters) + lookaround)
        return NSRange(location: start, length: max(0, end - start))
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        highlightedGeneration = -1
        scheduleHighlight()
        lineRuler.needsDisplay = true
    }

}
