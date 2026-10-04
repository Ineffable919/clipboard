import AppKit

extension JSONViewportEditor {
    func syncInput() {
        guard !suppressChanges, !textView.isHandlingInput, !textView.hasMarkedText() else { return }
        defer {
            pendingAnchor = nil
            pendingReplacement = nil
        }
        // 组合文本由原生控件管理，确认后只同步当前分页的实际差异
        if let edit = inputEdit() {
            let selected = textView.selectedRange()
            let start = pendingReplacement?.location ?? folds.sourceLocation(for: page.location)
            let range = NSRange(
                location: start + selected.location, length: selected.length
            )
            replace(edit.replacement, in: edit.range, anchor: pendingAnchor, selectedRange: range)
        } else {
            renderPage()
            textViewDidChangeSelection(Notification(name: NSTextView.didChangeSelectionNotification))
            scheduleHighlight()
        }
    }

    private func inputEdit() -> (range: NSRange, replacement: String)? {
        let previous = pageText as NSString
        let updated = textView.string as NSString
        var prefix = 0
        let limit = min(previous.length, updated.length)
        while prefix < limit, previous.character(at: prefix) == updated.character(at: prefix) { prefix += 1 }
        if prefix == previous.length, prefix == updated.length { return nil }
        if let pendingReplacement { return (pendingReplacement, textView.string) }
        if prefix > 0, (0xD800...0xDBFF).contains(previous.character(at: prefix - 1)) { prefix -= 1 }
        var suffix = 0
        while suffix < limit - prefix,
              previous.character(at: previous.length - suffix - 1)
                == updated.character(at: updated.length - suffix - 1) {
            suffix += 1
        }
        if suffix > 0, (0xDC00...0xDFFF).contains(previous.character(at: previous.length - suffix)) {
            suffix -= 1
        }
        let range = NSRange(location: page.location + prefix, length: previous.length - prefix - suffix)
        let replacement = updated.substring(with: NSRange(location: prefix, length: updated.length - prefix - suffix))
        return (folds.sourceRange(for: range), replacement)
    }
}
