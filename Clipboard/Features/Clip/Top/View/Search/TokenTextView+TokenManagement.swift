//
//  TokenTextView+TokenManagement.swift
//  Clipboard
//

import AppKit

extension TokenTextView {
    func insertToken(_ tag: InputTag) {
        insertTokens([tag])
    }

    func insertTokens(_ tags: [InputTag]) {
        guard !tags.isEmpty, let storage = textStorage else { return }

        storage.beginEditing()
        for tag in tags {
            let insertIndex = findTokenEndIndex()
            storage.insert(NSAttributedString.makeToken(for: tag), at: insertIndex)
            storage.insert(
                NSAttributedString(string: " ", attributes: plainTextAttributes),
                at: insertIndex + 1
            )
        }
        storage.endEditing()

        moveCursorToEnd()
        notifyTextChanged()
    }

    func removeToken(_ tag: InputTag) {
        guard let storage = textStorage else { return }

        let fullRange = NSRange(location: 0, length: storage.length)
        var foundRange: NSRange?

        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, stop in
            if let attachment = value as? TokenAttachment, attachment.tag == tag {
                foundRange = range
                stop.pointee = true
            }
        }

        guard let range = foundRange else { return }

        storage.beginEditing()
        let deleteRange = NSRange(
            location: range.location,
            length: min(range.length + 1, storage.length - range.location)
        )
        storage.deleteCharacters(in: deleteRange)
        storage.endEditing()

        setSelectedRange(NSRange(location: min(range.location, storage.length), length: 0))
        restorePlainTextInputState()
        notifyTextChanged()
    }

    func clearAllTokens() {
        guard let storage = textStorage else { return }

        let fullRange = NSRange(location: 0, length: storage.length)
        var rangesToDelete: [NSRange] = []

        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if value is NSTextAttachment {
                rangesToDelete.append(range)
            }
        }

        storage.beginEditing()
        for range in rangesToDelete.reversed() {
            let deleteRange = NSRange(
                location: range.location,
                length: min(range.length + 1, storage.length - range.location)
            )
            storage.deleteCharacters(in: deleteRange)
        }
        storage.endEditing()

        setSelectedRange(NSRange(location: 0, length: 0))
        restorePlainTextInputState()
        notifyTextChanged()
    }

    func getAllTokens() -> [InputTag] {
        guard let storage = textStorage else { return [] }

        var tokens: [InputTag] = []
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, _, _ in
            if let attachment = value as? TokenAttachment {
                tokens.append(attachment.tag)
            }
        }

        return tokens
    }

    func getPlainText() -> String {
        guard let storage = textStorage else { return "" }

        let mutableString = NSMutableString(string: storage.string)
        let fullRange = NSRange(location: 0, length: storage.length)
        var rangesToDelete: [NSRange] = []

        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if value is NSTextAttachment {
                rangesToDelete.append(range)
            }
        }

        for range in rangesToDelete.reversed() {
            mutableString.deleteCharacters(in: range)
        }

        return mutableString.trimmingCharacters(in: .whitespaces)
    }

    func findTokenEndIndex() -> Int {
        guard let storage = textStorage else { return 0 }

        var lastTokenEnd = 0
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if value is NSTextAttachment {
                lastTokenEnd = max(lastTokenEnd, range.location + range.length + 1)
            }
        }

        return lastTokenEnd
    }

    func notifyTextChanged() {
        onTextChanged?(getPlainText())
    }

    func selectToken(at location: Int) {
        guard selectedRange().length == 0,
              location >= 0,
              let storage = textStorage,
              location < storage.length,
              storage.attribute(.attachment, at: location, effectiveRange: nil) is TokenAttachment
        else { return }

        setSelectedRange(NSRange(location: location, length: 1))
    }

    func clearSelectedToken() {
        let selection = selectedRange()
        guard selection.length == 1,
              let storage = textStorage,
              selection.location < storage.length,
              storage.attribute(.attachment, at: selection.location, effectiveRange: nil) is TokenAttachment
        else { return }

        setSelectedRange(NSRange(location: NSMaxRange(selection), length: 0))
        restorePlainTextInputState()
        needsDisplay = true
    }

    func deleteSpacesBeforeCursor() -> Bool {
        let cursor = selectedRange()
        guard cursor.length == 0, let storage = textStorage else { return false }

        let text = storage.string as NSString
        var start = cursor.location
        while start > 0, text.character(at: start - 1) == unichar((" " as UnicodeScalar).value) {
            start -= 1
        }
        guard start > 0,
              start < cursor.location,
              storage.attribute(.attachment, at: start - 1, effectiveRange: nil) is TokenAttachment
        else { return false }

        storage.deleteCharacters(in: NSRange(location: start, length: cursor.location - start))
        setSelectedRange(NSRange(location: start - 1, length: 1))
        notifyTextChanged()
        return true
    }

    func deleteSelectedTokens(in range: NSRange) -> Bool {
        guard range.length > 0, let storage = textStorage else { return false }

        var tokensInRange: [InputTag] = []
        storage.enumerateAttribute(.attachment, in: range, options: []) { value, _, _ in
            if let attachment = value as? TokenAttachment {
                tokensInRange.append(attachment.tag)
            }
        }
        guard !tokensInRange.isEmpty else { return false }

        let storageLength = storage.length
        var extendedEnd = range.location + range.length
        let followsToken = range.location > 0
            && storage.attribute(.attachment, at: range.location - 1, effectiveRange: nil) is TokenAttachment
        // 前面的分隔空格已被删除时，保留后面的空格供剩余标签使用。
        if extendedEnd < storageLength, !followsToken {
            let nextCharacter = (storage.string as NSString).character(at: extendedEnd)
            if nextCharacter == unichar((" " as UnicodeScalar).value) {
                extendedEnd += 1
            }
        }

        let deleteRange = NSRange(
            location: range.location,
            length: min(extendedEnd - range.location, storageLength - range.location)
        )
        storage.beginEditing()
        storage.deleteCharacters(in: deleteRange)
        storage.endEditing()
        setSelectedRange(NSRange(location: range.location, length: 0))
        restorePlainTextInputState()

        for tag in tokensInRange {
            onTokenDeleted?(tag)
        }
        notifyTextChanged()
        return true
    }

    func deleteTokenBeforeCursor(at location: Int) -> Bool {
        guard let storage = textStorage,
              let attachment = storage.attribute(
                  .attachment,
                  at: location,
                  effectiveRange: nil
              ) as? TokenAttachment
        else { return false }

        onTokenDeleted?(attachment.tag)

        let nextLocation = location + 1
        let hasTrailingSpace = nextLocation < storage.length
            && (storage.string as NSString).character(at: nextLocation)
                == unichar((" " as UnicodeScalar).value)

        storage.beginEditing()
        let deleteRange = NSRange(
            location: location,
            length: hasTrailingSpace ? 2 : 1
        )
        storage.deleteCharacters(in: deleteRange)
        storage.endEditing()

        setSelectedRange(NSRange(location: location, length: 0))
        restorePlainTextInputState()
        notifyTextChanged()
        return true
    }
}
