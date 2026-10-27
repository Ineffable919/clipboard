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

        searchField.onTokensChanged = { [weak self] tags in
            guard let self, let topVM = self.topVM else { return }
            for tag in topVM.tags where !tags.contains(tag) {
                handleTokenDeletion(tag)
            }
        }

        topVM.filterDidChange
            .sink { [weak self] in
                self?.syncSearchTokens()
            }
            .store(in: &cancellables)

        topVM.clearQueryRequested
            .sink { [weak self] in
                self?.searchField.clearTextSilently()
            }
            .store(in: &cancellables)

        CategoryChipStore.shared.chipsContentDidChange
            .sink { [weak self] in
                guard let topVM = self?.topVM,
                      topVM.displayModeRaw == DisplayMode.drawer.rawValue
                else { return }
                topVM.refreshGroupTags()
            }
            .store(in: &cancellables)
    }

    private func syncSearchTokens() {
        guard let topVM else { return }
        if skipNextTokenSync {
            skipNextTokenSync = false
            updateChipSelection()
            return
        }

        searchField.clearTokensOnly()
        searchField.insertTokens(topVM.tags)
        updateChipSelection()
    }

    func handleTokenDeletion(_ tag: InputTag) {
        skipNextTokenSync = true
        topVM?.removeTag(tag)
    }

    func dismissFilterPopover() -> Bool {
        guard filterPopover?.isDisplayed == true else { return false }
        closeTarget = .search
        togglePopover()
        return true
    }

    func prepareFilterPopover() {
        guard filterPopover == nil, let topVM else { return }
        let controller = filterController ?? FilterPopoverViewController(viewModel: topVM)
        filterController = controller
        let popover = FilterPopover(viewController: controller)
        popover.onWillShow = { [weak self] in
            self?.searchField.setPopoverFocusRingSuppressed(true)
        }
        popover.onWillClose = { [weak self, weak popover] in
            guard let self, let popover, filterPopover === popover else { return }
            filterPopover = nil
            defer { searchField.setPopoverFocusRingSuppressed(false) }
            stopPopoverMonitor()
            handlePopoverWillClose()
        }
        filterPopover = popover
        popover.prepare()
    }

    func togglePopover() {
        prepareFilterPopover()
        guard let filterPopover else { return }
        if filterPopover.isDisplayed {
            closeTarget = .search
        } else {
            closeTarget = nil
        }
        filterPopover.toggle(
            relativeTo: searchField.filterButton.bounds,
            of: searchField.filterButton
        )
        if filterPopover.isDisplayed {
            startPopoverMonitor()
            onFocusRegionChange?(.filter)
        }
    }

    private func startPopoverMonitor() {
        stopPopoverMonitor()
        popoverMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .leftMouseDown
        ) { [weak self] event in
            guard let self,
                  filterPopover?.isDisplayed == true,
                  event.window === window,
                  let hitView = window?.contentView?.hitTest(event.locationInWindow)
            else {
                return event
            }

            if hitView === searchField || hitView.isDescendant(of: searchField) {
                closeTarget = .search
            } else {
                closeTarget = .clickedView
            }

            return event
        }
    }

    private func stopPopoverMonitor() {
        guard let popoverMouseMonitor else { return }
        NSEvent.removeMonitor(popoverMouseMonitor)
        self.popoverMouseMonitor = nil
    }

    func handlePopoverWillClose() {
        guard isSearching else {
            closeTarget = nil
            return
        }
        let target = resolveCloseTarget()
        if target != .search {
            window?.makeFirstResponder(nil)
            if topVM?.hasInput == false {
                deactivateSearch()
            }
            // 由点击目标接管焦点，不排队恢复尚未更新的旧选区。
            closeTarget = nil
            return
        }
        closeTarget = nil
        if !searchField.isFirstResponder {
            window?.makeFirstResponder(searchField.tokenTextView)
        }
        onFocusRegionChange?(.search)
    }

    private func resolveCloseTarget() -> CloseTarget {
        guard let event = NSApp.currentEvent,
              event.type == .leftMouseDown,
              event.window === window,
              let hitView = window?.contentView?.hitTest(event.locationInWindow)
        else {
            return closeTarget ?? .clickedView
        }

        if hitView === searchField || hitView.isDescendant(of: searchField) {
            return .search
        }

        return .clickedView
    }
}
