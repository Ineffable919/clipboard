//
//  SearchField+Suggestions.swift
//  Clipboard
//
//  Created by crown on 2026/8/19
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
        suggestionsTask?.cancel()
        suggestionsTask = nil
        if suggestionWindow.isVisible {
            suggestionWindow.hide()
        }
    }

    func updateSuggestions() {
        suggestionsTask?.cancel()
        suggestionsTask = nil
        let query = text
        guard !query.isEmpty, isFirstResponder, let provider = onSuggestionsNeeded else {
            hideSuggestions()
            return
        }

        suggestionsTask = Task { @MainActor [weak self] in
            do {
                let items = try await provider(query)
                try Task.checkCancellation()
                guard let self, text == query, isFirstResponder,
                      window?.isVisible == true, window?.isKeyWindow == true
                else { return }
                suggestionsTask = nil
                presentSuggestions(items, query: query)
            } catch is CancellationError {
                // 已取消的任务不能修改新请求的窗口或任务引用
            } catch {
                guard !Task.isCancelled else { return }
                self?.hideSuggestions()
            }
        }
    }

    private func presentSuggestions(_ items: [SearchSuggestionItem], query: String) {
        guard !items.isEmpty, let window = tokenTextView.window ?? window else {
            hideSuggestions()
            return
        }
        suggestionWindow.suggestionVC.reloadData(items, query: query)
        let origin = cursorScreenPosition()
        if suggestionWindow.isVisible {
            suggestionWindow.updateFrame(at: origin, items: items, query: query)
        } else {
            suggestionWindow.show(at: origin, items: items, query: query, parentWindow: window)
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
        guard suggestionsTask == nil else { return }
        hideSuggestions()
        onSuggestionSelected?(item)
    }
}
