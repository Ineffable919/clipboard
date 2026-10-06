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
                location: start + selected.location - inputOffset, length: selected.length
            )
            if richContent != nil {
                let location = pendingReplacement == nil ? edit.range.location - page.location : inputOffset
                let content = textView.attributedString().attributedSubstring(from: NSRange(
                    location: location, length: (edit.replacement as NSString).length
                ))
                replaceRich(content, in: edit.range, anchor: pendingAnchor, selectedRange: range)
            } else {
                replace(edit.replacement, in: edit.range, anchor: pendingAnchor, selectedRange: range)
            }
        } else {
            if let richContent {
                let content = textView.attributedString()
                if !content.isEqual(to: richContent.attributedSubstring(from: page)) {
                    let selected = textView.selectedRange()
                    replaceRich(content, in: page, anchor: pendingAnchor, selectedRange: NSRange(
                        location: page.location + selected.location, length: selected.length
                    ))
                    return
                }
            }
            renderPage()
            textViewDidChangeSelection(Notification(name: NSTextView.didChangeSelectionNotification))
            scheduleHighlight()
        }
    }

    private var inputOffset: Int {
        guard let pendingReplacement else { return 0 }
        let display = folds.displayRange(for: pendingReplacement)
        return min(page.length, max(0, display.location - page.location))
    }

    private func inputEdit() -> (range: NSRange, replacement: String)? {
        let previous = pageText as NSString
        let updated = textView.string as NSString
        var prefix = 0
        let limit = min(previous.length, updated.length)
        while prefix < limit, previous.character(at: prefix) == updated.character(at: prefix) { prefix += 1 }
        if let pendingReplacement {
            let display = folds.displayRange(for: pendingReplacement)
            let end = min(page.length, max(0, NSMaxRange(display) - page.location))
            let length = max(0, updated.length - inputOffset - (page.length - end))
            return (pendingReplacement, updated.substring(with: NSRange(location: inputOffset, length: length)))
        }
        if prefix == previous.length, prefix == updated.length { return nil }
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
