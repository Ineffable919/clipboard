//
//  SearchViewModel.swift
//  Clipboard
//
//  Created by crown
//

import Foundation
import SwiftUI

@Observable
final class SearchViewModel {
    var query: String = ""
    var isSearching: Bool = false

    private let dataStore: PasteDataStore
    private var searchTask: Task<Void, Never>?

    private var lastQuery: String = ""
    private var lastTypeFilter: [String]?
    private var lastGroup: Int = -1

    init(dataStore: PasteDataStore = .main) {
        self.dataStore = dataStore
    }

    func onSearchParametersChanged(
        typeFilter: [String]?,
        group: Int,
        selectedChipId: Int
    ) {
        searchTask?.cancel()

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

            guard !Task.isCancelled else { return }
            await searchClipboards(
                typeFilter: typeFilter,
                group: group,
                selectedChipId: selectedChipId
            )
        }
    }

    private func searchClipboards(
        typeFilter: [String]?,
        group: Int,
        selectedChipId: Int
    ) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuery == lastQuery,
           typeFilter == lastTypeFilter,
           group == lastGroup
        {
            return
        }

        if trimmedQuery.isEmpty, selectedChipId == 1 {
            dataStore.resetDefaultList()
            isSearching = false
        } else {
            dataStore.searchData(trimmedQuery, typeFilter, group)
            isSearching = true
        }

        lastQuery = trimmedQuery
        lastTypeFilter = typeFilter
        lastGroup = group
    }
}
