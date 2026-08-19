//
//  SearchField+Suggestions.swift
//  Clipboard
//

import AppKit

extension SearchField {
    func setupSuggestionKeyHandling() {
        tokenTextView.onKeyDown = { [weak self] event in
            self?.handleSuggestionKeyEvent(event) ?? false
        }

        suggestionWindow.suggestionVC.onSelectItem = { [weak self] item in
            self?.handleSuggestionItemSelected(item)
        }
    }

    private func handleSuggestionKeyEvent(_ event: NSEvent) -> Bool {
        guard suggestionWindow.isVisible else { return false }

        switch event.keyCode {
        case 125: // ↓
            return suggestionWindow.suggestionVC.selectNext()
        case 126: // ↑
            return suggestionWindow.suggestionVC.selectPrevious()
        case 36: // Enter
            return suggestionWindow.suggestionVC.applySelection()
        case 53: // Esc
            hideSuggestions()
            return true
        default:
            return false
        }
    }

    func showSuggestions() {
        updateSuggestions()
    }

    func hideSuggestions() {
        guard suggestionWindow.isVisible else { return }
        suggestionWindow.hide()
    }

    func updateSuggestions() {
        let query = text
        guard !query.isEmpty else {
            hideSuggestions()
            return
        }

        let items = onSuggestionsNeeded?(query) ?? []
        guard !items.isEmpty else {
            hideSuggestions()
            return
        }

        suggestionWindow.suggestionVC.reloadData(items, query: query)

        let cursorScreenOrigin = cursorScreenPosition()

        if !suggestionWindow.isVisible {
            guard let window = tokenTextView.window ?? window else { return }
            suggestionWindow.show(
                at: cursorScreenOrigin,
                items: items,
                query: query,
                parentWindow: window
            )
        } else {
            suggestionWindow.updateFrame(at: cursorScreenOrigin, items: items, query: query)
        }
    }

    private func cursorScreenPosition() -> NSPoint {
        guard let layoutManager = tokenTextView.layoutManager,
              let textContainer = tokenTextView.textContainer
        else {
            let fieldBounds = convert(bounds, to: nil)
            let screenFrame = window?.convertToScreen(fieldBounds) ?? .zero
            return NSPoint(x: screenFrame.origin.x, y: screenFrame.origin.y)
        }

        let insertionPoint = tokenTextView.selectedRange().location
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: insertionPoint, length: 0),
            actualCharacterRange: nil
        )
        let caretRect = layoutManager.boundingRect(
            forGlyphRange: glyphRange,
            in: textContainer
        )

        let inset = tokenTextView.textContainerInset
        let localPoint = NSPoint(
            x: caretRect.origin.x + inset.width,
            y: caretRect.maxY + inset.height
        )

        let windowPoint = tokenTextView.convert(localPoint, to: nil)
        return tokenTextView.window?.convertToScreen(
            NSRect(origin: windowPoint, size: .zero)
        ).origin ?? windowPoint
    }

    private func handleSuggestionItemSelected(_ item: SearchSuggestionItem) {
        hideSuggestions()
        onSuggestionSelected?(item)
    }
}
