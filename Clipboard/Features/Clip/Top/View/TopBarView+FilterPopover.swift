//
//  TopBarView+FilterPopover.swift
//  Clipboard
//
//  Filter Popover coordination and search-token synchronization.
//

import AppKit
import Combine

extension TopBarView {
    func setupTokenSync() {
        guard let topVM else { return }

        topVM.filterDidChange
            .sink { [weak self] in
                self?.syncTokensToSearchField()
            }
            .store(in: &cancellables)

        topVM.clearQueryRequested
            .sink { [weak self] in
                self?.searchField.clearTextSilently()
            }
            .store(in: &cancellables)

        CategoryChipStore.shared.chipsContentDidChange
            .sink { [weak self] in
                self?.topVM?.refreshGroupTags()
            }
            .store(in: &cancellables)
    }

    private func syncTokensToSearchField() {
        guard let topVM else { return }
        if shouldSkipNextTokenSync {
            shouldSkipNextTokenSync = false
            updateChipSelection()
            return
        }

        searchField.clearTokensOnly()
        searchField.insertTokens(topVM.tags)
        updateChipSelection()
    }

    func handleTokenDeletedFromSearchField(_ tag: InputTag) {
        shouldSkipNextTokenSync = true
        topVM?.removeTag(tag)
    }

    func dismissFilterPopoverIfVisible() -> Bool {
        guard filterPopover?.isShown == true else { return false }
        explicitFilterPopoverCloseDestination = .search
        togglePopover()
        return true
    }

    func togglePopover() {
        guard let filterPopover else { return }
        if filterPopover.isShown {
            explicitFilterPopoverCloseDestination = .search
        } else {
            explicitFilterPopoverCloseDestination = nil
        }
        filterPopover.toggle(
            relativeTo: searchField.filterButton.bounds,
            of: searchField.filterButton
        )
        if filterPopover.isShown {
            installFilterPopoverMouseMonitor()
            onFocusRegionChange?(.filter)
        }
    }

    private func installFilterPopoverMouseMonitor() {
        removeFilterPopoverMouseMonitor()
        filterPopoverMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .leftMouseDown
        ) { [weak self] event in
            guard let self,
                  filterPopover?.isShown == true,
                  event.window === window,
                  let hitView = window?.contentView?.hitTest(event.locationInWindow)
            else {
                return event
            }

            if hitView === searchField || hitView.isDescendant(of: searchField) {
                explicitFilterPopoverCloseDestination = .search
            } else {
                explicitFilterPopoverCloseDestination = .collection
            }

            return event
        }
    }

    private func removeFilterPopoverMouseMonitor() {
        guard let filterPopoverMouseMonitor else { return }
        NSEvent.removeMonitor(filterPopoverMouseMonitor)
        self.filterPopoverMouseMonitor = nil
    }

    func handlePopoverWillClose() {
        guard isSearching else {
            explicitFilterPopoverCloseDestination = nil
            return
        }
        let closeDestination = currentPopoverCloseDestination()
        if closeDestination == .collection {
            window?.makeFirstResponder(nil)
            if topVM?.hasInput == false {
                deactivateSearch()
            }
            if NSApp.currentEvent?.type == .leftMouseDown {
                Task { @MainActor [weak self] in
                    self?.onFocusRegionChange?(.collection)
                }
            } else {
                onFocusRegionChange?(.collection)
            }
            explicitFilterPopoverCloseDestination = nil
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { explicitFilterPopoverCloseDestination = nil }
            guard isSearching else { return }
            switch closeDestination {
            case .search:
                window?.makeFirstResponder(searchField.tokenTextView)
                onFocusRegionChange?(.search)
            case .collection:
                onFocusRegionChange?(.collection)
            }
        }
    }

    func handlePopoverDidClose() {
        removeFilterPopoverMouseMonitor()
    }

    private func currentPopoverCloseDestination() -> FilterPopoverCloseDestination {
        guard let event = NSApp.currentEvent,
              event.type == .leftMouseDown,
              event.window === window,
              let hitView = window?.contentView?.hitTest(event.locationInWindow)
        else {
            return explicitFilterPopoverCloseDestination ?? .collection
        }

        if hitView === searchField || hitView.isDescendant(of: searchField) {
            return .search
        }

        return .collection
    }
}
