//
//  TopBarView+Suggestions.swift
//  Clipboard
//
//  Search suggestion construction and application metadata loading.
//

import AppKit

extension TopBarView {
    func buildSuggestions(query: String) async throws -> [SearchSuggestionItem] {
        guard !query.isEmpty else { return [] }

        var suggestions = try await typeSuggestions(matching: query)
        suggestions += try await dateSuggestions(matching: query)
        suggestions += try await groupSuggestions(matching: query)
        suggestions += try await appSuggestions(matching: query)
        try Task.checkCancellation()
        return suggestions
    }

    private func typeSuggestions(matching query: String) async throws -> [SearchSuggestionItem] {
        let allTypes: [PasteModelType] = [.color, .file, .image, .link, .string]
        var suggestions: [SearchSuggestionItem] = []

        for (index, type) in allTypes.enumerated() {
            try await checkSuggestionCancellation(at: index)
            guard topVM?.selectedTypes.contains(type) != true else { continue }
            let (icon, label) = type.iconAndLabel
            guard fuzzyMatch(label, query: query) else { continue }
            let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
            suggestions.append(SearchSuggestionItem(
                title: label,
                icon: image,
                action: .toggleType(type)
            ))
        }

        return suggestions
    }

    private func dateSuggestions(matching query: String) async throws -> [SearchSuggestionItem] {
        var suggestions: [SearchSuggestionItem] = []

        for (index, option) in DateFilterOption.allCases.enumerated() {
            try await checkSuggestionCancellation(at: index)
            guard topVM?.selectedDateFilter != option else { continue }
            let label = option.displayName
            guard fuzzyMatch(label, query: query) else { continue }
            let image = NSImage(
                systemSymbolName: "calendar",
                accessibilityDescription: nil
            )
            suggestions.append(SearchSuggestionItem(
                title: label,
                icon: image,
                action: .setDate(option)
            ))
        }

        return suggestions
    }

    private func groupSuggestions(matching query: String) async throws -> [SearchSuggestionItem] {
        let userChips = CategoryChipStore.shared.chips.filter { !$0.isSystem }
        var suggestions: [SearchSuggestionItem] = []

        for (index, chip) in userChips.enumerated() {
            try await checkSuggestionCancellation(at: index)
            guard topVM?.selectedGroupIds.contains(chip.id) != true else {
                continue
            }
            guard fuzzyMatch(chip.name, query: query) else { continue }
            let dotIcon = makeChipDotIcon(colorIndex: chip.colorIndex)
            suggestions.append(SearchSuggestionItem(
                title: chip.name,
                icon: dotIcon,
                action: .setGroup(chip.id)
            ))
        }

        return suggestions
    }

    private func appSuggestions(matching query: String) async throws -> [SearchSuggestionItem] {
        var suggestions: [SearchSuggestionItem] = []

        for (index, app) in SourceAppCache.shared.orderedApps.enumerated() {
            try await checkSuggestionCancellation(at: index)
            guard topVM?.selectedAppIDs.contains(app.id) != true else { continue }
            guard fuzzyMatch(app.name, query: query) else { continue }
            suggestions.append(SearchSuggestionItem(
                title: app.name,
                icon: AppIconCache.shared.getCachedIcon(forAppID: app.id),
                action: .toggleApp(app.id)
            ))
        }

        return suggestions
    }

    private func checkSuggestionCancellation(at index: Int) async throws {
        if index.isMultiple(of: 32) {
            await Task.yield()
        }
        try Task.checkCancellation()
    }

    private func fuzzyMatch(_ text: String, query: String) -> Bool {
        let text = text.lowercased()
        let query = query.lowercased()
        var queryIndex = query.startIndex

        for char in text {
            if queryIndex < query.endIndex, char == query[queryIndex] {
                query.formIndex(after: &queryIndex)
            }
        }

        return queryIndex == query.endIndex
    }

    func handleSuggestionSelected(_ item: SearchSuggestionItem) {
        guard let topVM else { return }

        searchField.clearTextSilently()
        topVM.setQuery(text: "")

        switch item.action {
        case let .toggleType(type):
            topVM.toggleType(type)
        case let .toggleApp(id):
            topVM.toggleApp(id)
        case let .setDate(option):
            topVM.setDateFilter(option)
        case let .setGroup(id):
            topVM.toggleGroupFilter(id)
        }
    }

    private func makeChipDotIcon(colorIndex: Int) -> NSImage {
        CategoryDotRenderer.image(
            colorIndex: colorIndex,
            canvasSize: 18,
            diameter: 10
        )
    }
}
