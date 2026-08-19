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
        if extendedEnd < storageLength {
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

        storage.beginEditing()
        let deleteRange = NSRange(
            location: location,
            length: min(2, storage.length - location)
        )
        storage.deleteCharacters(in: deleteRange)
        storage.endEditing()

        setSelectedRange(NSRange(location: location, length: 0))
        restorePlainTextInputState()
        notifyTextChanged()
        return true
    }
}
