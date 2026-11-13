//
//  TopBarView+FilterPopover.swift
//  Clipboard
//
//  Created by crown on 2026/8/22
//
//  Filter Popover coordination and search-token synchronization
//

import AppKit
import Combine

extension TopBarView {
    func setupTokenSync() {
        guard let topVM else { return }

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
        searchField.setTokens(topVM.tags)
        updateChipSelection()
    }

    func dismissFilterPopover() -> Bool {
        guard filterPopover?.isDisplayed == true else { return false }
        closeTarget = .search
        togglePopover()
        return true
    }

    func prepareFilterPopover() {
        guard filterPopover == nil, let topVM else { return }
        // 旧弹窗仍在播放关闭动画时另取一个，保证连点时每次都能立即打开
        let popover = idlePopovers.popLast() ?? makeFilterPopover(viewModel: topVM)
        filterPopover = popover
        popover.prepare()
    }

    private func makeFilterPopover(viewModel: TopBarViewModel) -> FilterPopover {
        let popover = FilterPopover(viewController: FilterPopoverViewController(viewModel: viewModel))
        popover.onWillClose = { [weak self, weak popover] in
            guard let self, let popover, filterPopover === popover else { return }
            filterPopover = nil
            stopPopoverMonitor()
            handlePopoverWillClose()
        }
        popover.onDidClose = { [weak self, weak popover] in
            guard let self, let popover, filterPopover !== popover else { return }
            idlePopovers.append(popover)
        }
        return popover
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
            // 低版本系统连点时旧弹窗收尾会把 key 还给主窗口，搜索框随之重绘焦点环与光标；
            // 弹窗期间直接让出第一响应者，关闭时再按 closeTarget 恢复
            window?.makeFirstResponder(nil)
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
            // 由点击目标接管焦点，不排队恢复尚未更新的旧选区
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
