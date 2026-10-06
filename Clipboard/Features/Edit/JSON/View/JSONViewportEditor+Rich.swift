import AppKit

extension JSONViewportEditor {
    func registerRichUndo(_ range: NSRange, replacementLength: Int) {
        guard let richContent else { return }
        let previous = richContent.attributedSubstring(from: range)
        if range.location == 0, range.length == source.length {
            let prepared = JSONPreparedText(source: source, index: .init(blocks: blocks))
            undoManager?.registerUndo(withTarget: self) { target in
                target.restoreRich(previous, prepared: prepared)
            }
        } else {
            undoManager?.registerUndo(withTarget: self) { target in
                target.replaceRich(previous, in: NSRange(location: range.location, length: replacementLength))
            }
        }
    }

    func restoreRich(_ content: NSAttributedString, prepared: JSONPreparedText) {
        guard let richContent else { return }
        registerRichUndo(NSRange(location: 0, length: source.length), replacementLength: content.length)
        richContent.setAttributedString(content)
        source = prepared.source
        currentText = source as String
        blocks = prepared.index.blocks
        folds.reset()
        revision += 1
        selection = NSRange(location: 0, length: source.length)
        rebuildProjection()
        scrollView.contentView.scroll(to: .zero)
        refreshRich()
    }

    func replaceRich(
        _ content: NSAttributedString, in range: NSRange,
        anchor: (location: Int, offset: CGFloat)? = nil, selectedRange: NSRange? = nil
    ) {
        guard let richContent, range.location <= source.length, NSMaxRange(range) <= source.length else { return }
        registerRichUndo(range, replacementLength: content.length)
        var anchor = anchor ?? scrollAnchor()
        if range.location < anchor.location {
            anchor.location = anchor.location <= NSMaxRange(range)
                ? range.location + content.length : anchor.location + content.length - range.length
        }
        let unchanged = richContent.attributedSubstring(from: range).string == content.string
        richContent.replaceCharacters(in: range, with: content)
        revision += 1
        if !unchanged {
            source = richContent.string as NSString
            currentText = source as String
            updateIndexes(range: range, replacement: content.string)
        }
        selection = selectedRange ?? NSRange(location: range.location + content.length, length: 0)
        pageBlocks = 0..<0
        restoreScrollAnchor(anchor)
        if selection.location < page.location || selection.location > NSMaxRange(page) {
            scroll(to: selection.location)
        }
        suppressChanges = true
        restoreVisibleSelection()
        textView.scrollRangeToVisible(textView.selectedRange())
        suppressChanges = false
        onChange?(nil)
    }

    func refreshRich() {
        pageBlocks = 0..<0
        renderPage()
        onChange?(nil)
    }
}
