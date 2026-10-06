import AppKit

extension JSONEditorView {
    // MARK: - Editing Commands

    func insertIndent() {
        let spaces = String(repeating: " ", count: indentation.rawValue)
        textView.insertText(spaces, replacementRange: textView.selectedRange())
    }

    func insertNewline() {
        let source = textView.string as NSString
        let location = textView.selectedRange().location
        let lineRange = source.lineRange(for: NSRange(location: location, length: 0))
        let prefixRange = NSRange(
            location: lineRange.location,
            length: max(0, location - lineRange.location)
        )
        let prefix = source.substring(with: prefixRange)
        let leading = prefix.prefix(while: { $0 == " " || $0 == "\t" })
        let trimmed = prefix.trimmingCharacters(in: .whitespaces)
        let extra = trimmed.last == "{" || trimmed.last == "["
            ? String(repeating: " ", count: indentation.rawValue)
            : ""
        textView.insertText(
            "\n" + leading + extra,
            replacementRange: textView.selectedRange()
        )
    }
}

// MARK: - NSTextViewDelegate

extension JSONEditorView: NSTextViewDelegate {
    func textView(
        _: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        guard !isBusy else { return false }
        if foldedSource != nil {
            let range = folds.sourceRange(for: affectedCharRange)
            expandFolds()
            if let replacementString {
                textView.insertText(replacementString, replacementRange: range)
            }
            return false
        }
        pendingEdit = replacementString.map {
            (range: affectedCharRange, replacement: $0)
        }
        return true
    }

    func textDidChange(_: Notification) {
        guard !suppressChanges else { return }
        generation += 1
        updateLineIndexAfterTextChange()
        scheduleHighlight()
        scheduleFoldIndex()
        knownValidity = nil
        onTextChange?(nil)
    }

    func textViewDidChangeSelection(_: Notification) {
        guard !suppressChanges, isLineIndexReady,
              textView.selectedRange() != reportedSelection
              || lineIndexRevision != reportedLineIndexRevision
        else { return }
        updateCursor()
    }

    func textView(_: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertTab(_:)):
            insertIndent()
            return true
        case #selector(NSResponder.insertNewline(_:)):
            insertNewline()
            return true
        default:
            return false
        }
    }
}

// MARK: - NSTextStorageDelegate

extension JSONEditorView: NSTextStorageDelegate {
    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range _: NSRange,
        changeInLength delta: Int
    ) {
        guard !suppressChanges,
              editedMask.contains(.editedCharacters)
        else { return }

        let edit: (range: NSRange, replacement: String)?
        if let pendingEdit,
           pendingEdit.replacement.utf16.count - pendingEdit.range.length == delta {
            edit = pendingEdit
        } else {
            let markedRange = textView.markedRange()
            let replacedRange = markedRange.location == NSNotFound
                ? textView.selectedRange()
                : markedRange
            let replacementLength = replacedRange.length + delta
            guard delta != 0,
                  replacementLength >= 0
            else {
                pendingEdit = nil
                return
            }

            let replacementRange = NSRange(
                location: replacedRange.location,
                length: replacementLength
            )
            guard replacementRange.location <= textStorage.length,
                  NSMaxRange(replacementRange) <= textStorage.length
            else {
                pendingEdit = nil
                shouldRebuildLineIndex = true
                return
            }

            edit = (
                range: replacedRange,
                replacement: textStorage.attributedSubstring(from: replacementRange).string
            )
        }
        pendingEdit = nil

        guard let edit else { return }
        guard isLineIndexReady,
              edit.range.location <= textStorage.length,
              max(edit.range.length, edit.replacement.utf16.count) <= 65536
        else {
            shouldRebuildLineIndex = true
            return
        }

        lineIndex.applyReplacement(
            range: edit.range,
            replacement: edit.replacement
        )
        lineIndexRevision &+= 1
    }
}
