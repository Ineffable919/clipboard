//
//  TokenTextView+TokenManagement.swift
//  Clipboard
//

import AppKit

extension TokenTextView {
    /// 只替换标签前缀，保留原始文字及文字区域中的选区
    func replaceTokens(_ tags: [InputTag]) {
        guard let storage = textStorage else { return }
        let current = getAllTokens()
        guard current.count != tags.count || zip(current, tags).contains(where: {
            $0 != $1 || $0.label != $1.label || $0.icon !== $1.icon
        }) else { return }

        let oldEnd = min(findTokenEndIndex(), storage.length)
        let selection = selectedRange()
        let prefix = NSMutableAttributedString()
        for tag in tags {
            prefix.append(.makeToken(for: tag))
            prefix.append(NSAttributedString(string: " ", attributes: plainTextAttributes))
        }
        storage.replaceCharacters(in: NSRange(location: 0, length: oldEnd), with: prefix)
        let start = current == tags ? selection.location : prefix.length + max(0, selection.location - oldEnd)
        let end = current == tags ? NSMaxRange(selection) : prefix.length + max(0, NSMaxRange(selection) - oldEnd)
        let boundedStart = min(start, storage.length)
        setSelectedRange(NSRange(location: boundedStart, length: max(0, min(end, storage.length) - boundedStart)))
        restorePlainTextInputState()
        scrollRangeToVisible(selectedRange())
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
                var end = NSMaxRange(range)
                if end < storage.length, (storage.string as NSString).character(at: end) == 0x20 {
                    end += 1
                }
                lastTokenEnd = max(lastTokenEnd, end)
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
        // 前面的分隔空格已被删除时，保留后面的空格供剩余标签使用
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

        notifyTextChanged()
        return true
    }

    func deleteTokenBeforeCursor(at location: Int) -> Bool {
        guard let storage = textStorage,
              storage.attribute(
                  .attachment,
                  at: location,
                  effectiveRange: nil
              ) is TokenAttachment
        else { return false }

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
