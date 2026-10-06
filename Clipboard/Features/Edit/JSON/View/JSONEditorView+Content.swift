import AppKit

extension JSONEditorView {
    // MARK: - Content

    func setText(
        _ text: String,
        document: JSONFoldIndex.Document? = nil,
        preparedText: JSONPreparedText? = nil,
        resettingUndo: Bool = true
    ) {
        if let preparedText {
            installViewport(text, document: document, prepared: preparedText)
            return
        }
        viewport?.removeFromSuperview()
        viewport = nil
        scrollView.isHidden = false
        lineRuler.isHidden = false
        foldedSource = nil
        folds.reset()
        lineTask?.cancel()
        lineNumberTask?.cancel()
        cancelHighlight()
        pendingEdit = nil
        clearHighlight()
        suppressChanges = true
        textView.undoManager?.disableUndoRegistration()
        textView.typingAttributes = baseTextAttributes
        textView.string = text
        textView.typingAttributes = baseTextAttributes
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.undoManager?.enableUndoRegistration()
        if resettingUndo { textView.undoManager?.removeAllActions() }
        suppressChanges = false
        generation += 1
        if let document {
            lineIndex.replace(with: document.lineStarts)
            lineIndexRevision &+= 1
            isLineIndexReady = true
            updateCursor()
        } else {
            rebuildLineIndex(for: text, generation: generation)
        }
        invalidateTextDisplay()
        scheduleHighlight()
        if let document {
            foldTask?.cancel()
            foldRequestID &+= 1
            folds.reset(nodes: document.nodes)
            scheduleLineNumberRefresh(immediately: true)
        } else {
            scheduleFoldIndex(immediately: true, source: text)
        }
    }

    func transformTarget() -> (text: String, range: NSRange) {
        let selection = viewport?.selection ?? folds.sourceRange(for: textView.selectedRange())
        let source = currentText as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let range = selection.length > 0 ? selection : fullRange
        let text = range == fullRange ? currentText : source.substring(with: range)
        return (text, range)
    }

    @discardableResult
    func replaceText(
        _ text: String,
        in range: NSRange,
        document: JSONFoldIndex.Document? = nil,
        previousText preparedPreviousText: String? = nil,
        preparedText: JSONPreparedText? = nil,
        knownValidity: Bool? = nil,
        registeringUndo: Bool = true
    ) -> Bool {
        let source = currentText as NSString
        guard range.location <= source.length,
              NSMaxRange(range) <= source.length
        else { return false }

        let previousText = preparedPreviousText ?? source.substring(with: range)
        let previousValidity = self.knownValidity
        let entireDocument = range.location == 0 && range.length == source.length
        let replacementValidity = entireDocument ? knownValidity : nil
        if viewport != nil || preparedText != nil {
            return replaceViewport(
                text, replacement: JSONViewportReplacement(
                    range: range, entireDocument: entireDocument, index: document, prepared: preparedText,
                    previousText: previousText, previousValidity: previousValidity,
                    validity: replacementValidity, registeringUndo: registeringUndo
                ), viewport: viewport
            )
        }
        guard preparedPreviousText != nil || !(previousText as NSString).isEqual(to: text),
              let textStorage = textView.textStorage
        else { return false }

        expandFolds()
        let replacementLength = text.utf16.count

        window?.disableScreenUpdatesUntilFlush()
        cancelHighlight()
        suppressChanges = true
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: range, with: text)
        textStorage.setAttributes(
            baseTextAttributes,
            range: NSRange(location: range.location, length: replacementLength)
        )
        textStorage.endEditing()
        suppressChanges = false

        if registeringUndo {
            registerReplacementUndo(text, previous: previousText, range: range,
                                    validity: replacementValidity, entireDocument: entireDocument)
        }
        applyIndexes(document)
        resetScroll()
        invalidateTextDisplay()
        scheduleHighlight()
        self.knownValidity = replacementValidity
        onTextChange?(document?.statisticsLineCount)
        window?.contentView?.needsDisplay = true
        return true
    }

    private func clearHighlight() {
        if highlightedRange.length > 0, let layoutManager = textView.layoutManager {
            let currentRange = NSRange(location: 0, length: textView.string.utf16.count)
            let removableRange = NSIntersectionRange(highlightedRange, currentRange)
            if removableRange.length > 0 {
                layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: removableRange)
            }
        }
        highlightedRange = NSRange(location: 0, length: 0)
    }

    private func registerReplacementUndo(
        _ text: String, previous: String, range: NSRange, validity: Bool?, entireDocument: Bool
    ) {
        let previousValidity = knownValidity
        let length = text.utf16.count
        textView.undoManager?.registerUndo(withTarget: self) { target in
            if entireDocument, max(range.length, length) >= 1_048_576 {
                target.restoreDocument(
                    previous, validity: previousValidity, reversing: text, oppositeValidity: validity
                )
            } else {
                target.replaceText(previous, in: NSRange(location: range.location, length: length),
                                   knownValidity: previousValidity)
            }
        }
    }

    private func resetScroll() {
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        let clipView = scrollView.contentView
        var targetBounds = clipView.bounds
        targetBounds.origin = .zero
        let constrainedBounds = clipView.constrainBoundsRect(targetBounds)
        clipView.scroll(to: constrainedBounds.origin)
        scrollView.reflectScrolledClipView(clipView)
    }

    private func applyIndexes(_ document: JSONFoldIndex.Document?) {
        if let document {
            generation &+= 1
            lineTask?.cancel()
            foldTask?.cancel()
            foldRequestID &+= 1
            pendingEdit = nil
            shouldRebuildLineIndex = false
            lineIndex.replace(with: document.lineStarts)
            lineIndexRevision &+= 1
            isLineIndexReady = true
            folds.reset(nodes: document.nodes)
        } else {
            rebuildIndexesAfterReplacement()
        }
    }

    func restoreDocument(
        _ text: String, validity: Bool?, reversing opposite: String, oppositeValidity: Bool?
    ) {
        // 在 UndoManager 的撤销回调中立即登记反向操作，计算与显示可稍后完成
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreDocument(opposite, validity: oppositeValidity, reversing: text, oppositeValidity: validity)
        }
        restoreTask?.cancel()
        isBusy = true
        let width = preparationWidth
        restoreTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                JSONDocument.prepare(text, knownValidity: validity, width: width)
            }
            let document = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard let self, !Task.isCancelled else { return }
            defer { isBusy = false }
            replaceText(
                document.text, in: NSRange(location: 0, length: (currentText as NSString).length),
                document: document.index, previousText: opposite,
                preparedText: document.preparedText, knownValidity: document.isValid, registeringUndo: false
            )
        }
    }

    func focus(revealingSelection: Bool = true) {
        if let viewport { viewport.focus(); return }
        window?.makeFirstResponder(textView)
        if revealingSelection {
            textView.scrollRangeToVisible(textView.selectedRange())
        }
        invalidateTextDisplay()
        scheduleHighlight()
    }

    func installViewport(_ text: String, document: JSONFoldIndex.Document?, prepared: JSONPreparedText) {
        cancelHighlight()
        lineTask?.cancel()
        lineNumberTask?.cancel()
        foldTask?.cancel()
        scrollView.isHidden = true
        lineRuler.isHidden = true
        if viewport == nil {
            viewport = makeViewport()
        }
        layoutSubtreeIfNeeded()
        viewport?.setText(text, document: document, prepared: prepared)
        viewport?.focus()
    }

    /// 首屏排版稳定后重置滚动位置，避免长文档后续调整高度时偏离顶部
    func scrollToTop() {
        if let viewport { viewport.scrollToTop(); return }
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        layoutSubtreeIfNeeded()
        let clipView = scrollView.contentView
        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            layoutManager.ensureLayout(
                forBoundingRect: NSRect(origin: .zero, size: clipView.bounds.size),
                in: textContainer
            )
            textView.sizeToFit()
        }
        var targetBounds = clipView.bounds
        targetBounds.origin = .zero
        let constrainedBounds = clipView.constrainBoundsRect(targetBounds)
        clipView.scroll(to: constrainedBounds.origin)
        scrollView.reflectScrolledClipView(clipView)
    }

    func invalidateTextDisplay() {
        let range = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
        if range.length > 0 {
            textView.layoutManager?.invalidateDisplay(forCharacterRange: range)
        }
        textView.needsDisplay = true
    }

}
