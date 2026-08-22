//
//  TopBarView+Suggestions.swift
//  Clipboard
//
//  Search suggestion construction and application metadata loading.
//

import AppKit

extension TopBarView {
    func buildSuggestions(query: String) -> [SearchSuggestionItem] {
        guard !query.isEmpty else { return [] }

        return typeSuggestions(matching: query)
            + dateSuggestions(matching: query)
            + groupSuggestions(matching: query)
            + appSuggestions(matching: query)
    }

    private func typeSuggestions(matching query: String) -> [SearchSuggestionItem] {
        let allTypes: [PasteModelType] = [.color, .file, .image, .link, .string]
        var suggestions: [SearchSuggestionItem] = []

        for type in allTypes {
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

    private func dateSuggestions(matching query: String) -> [SearchSuggestionItem] {
        var suggestions: [SearchSuggestionItem] = []

        for option in DateFilterOption.allCases {
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

    private func groupSuggestions(matching query: String) -> [SearchSuggestionItem] {
        let userChips = CategoryChipStore.shared.chips.filter { !$0.isSystem }
        var suggestions: [SearchSuggestionItem] = []

        for chip in userChips {
            guard topVM?.selectedGroupId != chip.id else { continue }
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

    private func appSuggestions(matching query: String) -> [SearchSuggestionItem] {
        guard let cachedAppSuggestions else { return [] }
        var suggestions: [SearchSuggestionItem] = []

        for app in cachedAppSuggestions {
            guard topVM?.selectedAppNames.contains(app.name) != true else { continue }
            guard fuzzyMatch(app.name, query: query) else { continue }
            suggestions.append(SearchSuggestionItem(
                title: app.name,
                icon: app.icon,
                action: .toggleApp(app.name, app.path)
            ))
        }

        return suggestions
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
        case let .toggleApp(name, path):
            topVM.toggleApp(name, appPath: path)
        case let .setDate(option):
            topVM.setDateFilter(option)
        case let .setGroup(id):
            topVM.setGroupFilter(id)
        }
    }

    func loadAppSuggestionsIfNeeded() {
        guard cachedAppSuggestions == nil,
              appSuggestionsLoadingTask == nil
        else {
            return
        }
        appSuggestionsLoadingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { appSuggestionsLoadingTask = nil }

            let appInfo = await PasteMetadataCache.shared.getAllAppInfo()
            var suggestions: [AppSuggestionInfo] = []
            for info in appInfo {
                let icon = await AppIconCache.shared.loadIcon(forPath: info.path)
                suggestions.append(AppSuggestionInfo(
                    name: info.name,
                    path: info.path,
                    icon: icon
                ))
            }
            cachedAppSuggestions = suggestions

            if !searchField.text.isEmpty {
                searchField.showSuggestions()
            }
        }
    }

    private func makeChipDotIcon(colorIndex: Int) -> NSImage {
        let canvasSize: CGFloat = 14
        let dotSize: CGFloat = 10
        let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
        image.lockFocus()
        let color = CategoryChip.nsColor(at: colorIndex)
        color.setFill()
        let origin = (canvasSize - dotSize) / 2
        NSBezierPath(
            ovalIn: NSRect(x: origin, y: origin, width: dotSize, height: dotSize)
        ).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
