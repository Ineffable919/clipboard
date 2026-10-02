import AppKit

// MARK: - Original text coordinates and undo

extension JSONViewportEditor {
    func selectedText() -> String {
        selection.location == 0 && selection.length == source.length
            ? currentText : source.substring(with: selection)
    }

    func selectAll() {
        selection = NSRange(location: 0, length: source.length)
        suppressChanges = true
        restoreVisibleSelection()
        suppressChanges = false
        updateCursor()
    }

    func prepareEdit(_ range: NSRange) -> NSRange {
        if pendingAnchor == nil, !textView.isHandlingInput, !textView.hasMarkedText() {
            pendingAnchor = scrollAnchor()
            if selection.length > textView.selectedRange().length { pendingReplacement = selection }
        }
        guard !folds.collapsed.isEmpty else { return range }
        let anchor = scrollAnchor()
        let target = range.location == NSNotFound ? selection : folds.sourceRange(for: NSRange(
            location: page.location + range.location, length: range.length
        ))
        folds.reset(nodes: folds.nodes)
        rebuildProjection()
        selection = target
        restoreScrollAnchor(anchor)
        if target.location < page.location || target.location > NSMaxRange(page) { scroll(to: target.location) }
        restoreVisibleSelection()
        return NSRange(location: target.location - page.location, length: target.length)
    }

    func updateCursor() {
        let position = lineIndex.lineAndColumn(at: selection.location)
        ruler.update(lineCount: lineIndex.lineCount, currentLine: position.line)
        onCursor?(position.line, position.column)
    }

    func move(_ selector: Selector) -> Bool {
        let command = NSStringFromSelector(selector)
        let end = NSMaxRange(selection)
        var location: Int?
        switch command {
        case "moveToBeginningOfDocument:": location = 0
        case "moveToEndOfDocument:": location = source.length
        case "moveLeft:" where selection.location <= folds.sourceLocation(for: page.location):
            location = max(0, selection.location - 1)
        case "moveRight:" where end >= folds.sourceLocation(for: NSMaxRange(page)):
            location = min(source.length, end + 1)
        default: break
        }
        guard let location else { return false }
        selection = NSRange(location: location, length: 0)
        scroll(to: location)
        suppressChanges = true
        restoreVisibleSelection()
        textView.scrollRangeToVisible(textView.selectedRange())
        suppressChanges = false
        updateCursor()
        return true
    }

    func updateIndexes(range: NSRange, replacement: String) {
        let first = blocks.firstIndex { NSMaxRange($0.range) > range.location } ?? max(0, blocks.count - 1)
        let last = blocks.lastIndex { $0.range.location <= NSMaxRange(range) } ?? first
        let delta = (replacement as NSString).length - range.length
        let start = blocks[first].range.location
        let end = NSMaxRange(blocks[last].range) + delta
        let changed = JSONViewportIndex.build(source, range: NSRange(location: start, length: end - start)).blocks
        blocks.replaceSubrange(first...last, with: changed)
        let next = first + changed.count
        if next < blocks.count {
            for index in next..<blocks.count { blocks[index].range.location += delta }
        }
        lineIndex.applyReplacement(range: range, replacement: replacement)
        folds.reset()
        rebuildProjection()
    }

    func updateFoldIndex() {
        indexTask?.cancel()
        let text = currentText
        let revision = revision
        indexTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let worker = Task.detached(priority: .utility) { JSONFoldIndex.build(for: text) }
            let nodes = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            guard let self, !Task.isCancelled, revision == self.revision else { return }
            folds.reset(nodes: nodes)
            ruler.refreshVisibleLines()
        }
    }
}

extension JSONViewportEditor {
    func replace(
        _ text: String, in range: NSRange, registeringUndo: Bool = true,
        anchor: (location: Int, offset: CGFloat)? = nil, selectedRange: NSRange? = nil
    ) {
        guard range.location <= source.length, NSMaxRange(range) <= source.length else { return }
        var anchor = anchor ?? scrollAnchor()
        let previous = source.substring(with: range)
        let replacementLength = (text as NSString).length
        if range.location < anchor.location {
            anchor.location = anchor.location <= NSMaxRange(range)
                ? range.location + replacementLength : anchor.location + replacementLength - range.length
        }
        if registeringUndo {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replace(previous, in: NSRange(location: range.location, length: replacementLength))
            }
        }
        source = source.replacingCharacters(in: range, with: text) as NSString
        currentText = source as String
        revision += 1
        updateIndexes(range: range, replacement: text)
        selection = selectedRange ?? NSRange(location: range.location + replacementLength, length: 0)
        restoreScrollAnchor(anchor)
        let display = folds.displayLocation(for: selection.location)
        if display < page.location || display > NSMaxRange(page) { scroll(to: selection.location) }
        suppressChanges = true
        restoreVisibleSelection()
        textView.scrollRangeToVisible(textView.selectedRange())
        suppressChanges = false
        updateCursor()
        updateFoldIndex()
        onChange?(lineIndex.lineCount)
    }
}

extension JSONViewportEditor: NSTextViewDelegate {
    func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
        guard isEditable else { return false }
        if suppressChanges { return true }
        if pendingAnchor == nil, !textView.hasMarkedText() { pendingAnchor = scrollAnchor() }
        return true
    }

    func textDidChange(_ notification: Notification) {
        syncInput()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !suppressChanges, !textView.isHandlingInput, !textView.hasMarkedText() else { return }
        selection = folds.sourceRange(for: NSRange(
            location: page.location + textView.selectedRange().location, length: textView.selectedRange().length
        ))
        updateCursor()
    }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertTab(_:)):
            textView.insertText(
                String(repeating: " ", count: indentation.rawValue), replacementRange: textView.selectedRange()
            )
            return true
        case #selector(NSResponder.insertNewline(_:)):
            let line = source.lineRange(for: NSRange(location: selection.location, length: 0))
            let prefixRange = NSRange(location: line.location, length: selection.location - line.location)
            let prefix = source.substring(with: prefixRange)
            let leading = prefix.prefix { $0 == " " || $0 == "\t" }
            let extra = prefix.trimmingCharacters(in: .whitespaces).last.map { $0 == "{" || $0 == "[" } ?? false
            let indent = extra ? String(repeating: " ", count: indentation.rawValue) : ""
            textView.insertText("\n" + leading + indent, replacementRange: textView.selectedRange())
            return true
        default: return false
        }
    }
}
