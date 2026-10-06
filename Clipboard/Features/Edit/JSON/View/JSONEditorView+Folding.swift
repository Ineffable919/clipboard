import AppKit

// MARK: - Folding

extension JSONEditorView {
    func setupFolding() {
        textView.onPrepareEdit = { [weak self] range in
            self?.prepareEdit(in: range) ?? range
        }
        textView.onExpand = { [weak self] in self?.expandFolds() }
        textView.onCopy = { [weak self] range in
            guard let self else { return "" }
            return (currentText as NSString).substring(with: folds.sourceRange(for: range))
        }
        lineRuler.sourceLocation = { [weak self] location in
            self?.folds.sourceLocation(for: location) ?? location
        }
        lineRuler.foldAtLine = { [weak self] location in
            guard let self, let node = folds.node(atLineStart: location) else { return nil }
            return (node, folds.collapsed.contains(node))
        }
        lineRuler.onToggleFold = { [weak self] node in self?.toggleFold(node) }
        for name in [Notification.Name.NSUndoManagerWillUndoChange, .NSUndoManagerWillRedoChange] {
            NotificationCenter.default.addObserver(self, selector: #selector(prepareUndo(_:)), name: name, object: nil)
        }
    }

    func rebuildIndexesAfterReplacement() {
        generation += 1
        pendingEdit = nil
        shouldRebuildLineIndex = false
        rebuildLineIndex(for: textView.string, generation: generation)
        scheduleFoldIndex(immediately: true)
    }

    func scheduleFoldIndex(immediately: Bool = false, source initialSource: String? = nil) {
        foldTask?.cancel()
        foldRequestID &+= 1
        let requestID = foldRequestID
        folds.reset()
        scheduleLineNumberRefresh(immediately: true)
        foldTask = Task { @MainActor [weak self] in
            if !immediately {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard let self, !Task.isCancelled else { return }
            let source = initialSource ?? currentText
            let worker = Task.detached(priority: .utility) {
                JSONFoldIndex.build(for: source)
            }
            let nodes = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled, requestID == foldRequestID else { return }
            folds.reset(nodes: nodes)
            scheduleLineNumberRefresh(immediately: true)
        }
    }

    func toggleFold(_ node: Int) {
        guard !isBusy, !textView.hasMarkedText(), folds.nodes.indices.contains(node) else { return }
        let body = folds.nodes[node].body
        let displayRange = folds.displayRange(for: body)
        let selection = folds.sourceRange(for: textView.selectedRange())
        if foldedSource == nil {
            foldedSource = textView.string
        }
        let source = currentText as NSString
        folds.toggle(node)
        let replacement = folds.text(in: source, range: body)
        updateFoldDisplay(selection: folds.displayRange(for: selection)) { storage in
            storage.replaceCharacters(in: displayRange, with: replacement)
            storage.setAttributes(
                baseTextAttributes,
                range: NSRange(location: displayRange.location, length: replacement.utf16.count)
            )
        }
        if folds.collapsed.isEmpty {
            foldedSource = nil
        }
    }

    func expandFolds() {
        guard let foldedSource else { return }
        let source = foldedSource as NSString
        let segments = folds.segments
        let selection = folds.sourceRange(for: textView.selectedRange())
        folds.reset(nodes: folds.nodes)
        updateFoldDisplay(selection: selection) { storage in
            for segment in segments.reversed() {
                storage.replaceCharacters(in: segment.display, with: source.substring(with: segment.source))
                storage.setAttributes(
                    baseTextAttributes,
                    range: NSRange(location: segment.display.location, length: segment.source.length)
                )
            }
        }
        self.foldedSource = nil
    }

    func updateFoldDisplay(selection: NSRange, edit: (NSTextStorage) -> Void) {
        guard let storage = textView.textStorage else { return }
        let clipView = scrollView.contentView
        let origin = clipView.bounds.origin
        window?.disableScreenUpdatesUntilFlush()
        cancelHighlight()
        let highlighted = NSIntersectionRange(highlightedRange, NSRange(location: 0, length: storage.length))
        if highlighted.length > 0 {
            textView.layoutManager?.removeTemporaryAttribute(.foregroundColor, forCharacterRange: highlighted)
        }
        highlightedRange = NSRange(location: 0, length: 0)
        suppressChanges = true
        storage.beginEditing()
        edit(storage)
        storage.endEditing()
        textView.setSelectedRange(selection)
        suppressChanges = false
        generation &+= 1
        var bounds = clipView.bounds
        bounds.origin = origin
        clipView.scroll(to: clipView.constrainBoundsRect(bounds).origin)
        scrollView.reflectScrolledClipView(clipView)
        updateCursor()
        scheduleLineNumberRefresh(immediately: true)
        scheduleHighlight()
    }

    func prepareEdit(in range: NSRange) -> NSRange {
        guard foldedSource != nil else { return range }
        let displayRange = range.location == NSNotFound ? textView.selectedRange() : range
        let sourceRange = folds.sourceRange(for: displayRange)
        expandFolds()
        return sourceRange
    }

    @objc func prepareUndo(_ notification: Notification) {
        guard let manager = notification.object as? UndoManager,
              manager === textView.undoManager else { return }
        expandFolds()
    }
}
