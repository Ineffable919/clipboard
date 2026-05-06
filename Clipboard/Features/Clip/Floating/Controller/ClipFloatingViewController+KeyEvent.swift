//
//  ClipFloatingViewController+KeyEvent.swift
//  Clipboard
//
//  Created by crown on 2026/5/4.
//

import AppKit

extension ClipFloatingViewController {
    // MARK: - Event Handlers

    func keyDownEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window == ClipFloatingWindowController.shared.window else {
            return event
        }

        let historyView = floatingContentView.historyView

        if focusRegion == .popover {
            if event.keyCode == KeyCode.escape {
                closePreview()
                return nil
            }
            return event
        }

        if focusRegion == .search {
            if event.keyCode == KeyCode.escape {
                return searchEscapeKeyDown()
            }
            return event
        }

        if let index = quickPasteIndex(for: event) {
            performQuickPaste(at: index)
            return nil
        }

        if KeyCode.shouldTriggerSearch(for: event),
           focusRegion != .search,
           floatingContentView.headerView.searchField.currentEditor() == nil
        {
            historyView.activateSearchField(with: event.characters)
            return nil
        }

        if handleChipTab(event, viewModel: floatingContentView.topVM) {
            return nil
        }

        if event.modifierFlags.contains(.command) {
            return commandKeyDown(event)
        }

        switch event.keyCode {
        case KeyCode.escape:
            return escapeKeyDown()

        case KeyCode.space:
            return spaceKeyDown()

        case KeyCode.return, KeyCode.keypadEnter:
            return returnKeyDown(event)

        case KeyCode.delete, KeyCode.forwardDelete:
            historyView.requestDelete(at: historyView.selectedIndex)
            return nil

        default:
            return event
        }
    }

    func flagsChangedEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window == ClipFloatingWindowController.shared.window,
              ClipFloatingWindowController.shared.isVisible,
              floatingContentView.historyView.collectionView.isFirstResponder
        else { return event }

        isQuickPastePressed = KeyCode.isQuickPasteModifierPressed()
        return event
    }

    // MARK: - Key Handlers

    private func searchEscapeKeyDown() -> NSEvent? {
        let searchField = floatingContentView.headerView.searchField
        if !searchField.stringValue.isEmpty {
            floatingContentView.headerView.clearSearch()
        } else {
            let historyView = floatingContentView.historyView
            view.window?.makeFirstResponder(historyView.collectionView)
            historyView.setFocusRegion(.collection)
        }
        return nil
    }

    private func escapeKeyDown() -> NSEvent? {
        if previewPopover != nil {
            closePreview()
        } else {
            ClipFloatingWindowController.shared.toggleWindow()
        }
        return nil
    }

    private func spaceKeyDown() -> NSEvent? {
        guard focusRegion == .collection else { return nil }
        let index = floatingContentView.historyView.selectedIndex
        togglePreview(at: index)
        return nil
    }

    private func returnKeyDown(_ event: NSEvent) -> NSEvent? {
        guard focusRegion == .collection else { return nil }
        let historyView = floatingContentView.historyView
        let isAttribute = !KeyCode.hasModifier(
            event,
            modifierIndex: PasteUserDefaults.plainTextModifier
        )
        historyView.pasteItem(
            at: historyView.selectedIndex,
            isAttribute: isAttribute
        )
        return nil
    }

    private func commandKeyDown(_ event: NSEvent) -> NSEvent? {
        let hasExtra = !event.modifierFlags.intersection([
            .option, .control, .shift,
        ]).isEmpty
        guard !hasExtra else { return nil }

        let historyView = floatingContentView.historyView
        switch event.keyCode {
        case KeyCode.c:
            historyView.copyItem(at: historyView.selectedIndex)
            return nil
        case KeyCode.e:
            historyView.openEditWindow(at: historyView.selectedIndex)
            return nil
        default:
            return nil
        }
    }

    private func handleChipTab(_ event: NSEvent, viewModel: TopBarViewModel)
        -> Bool
    {
        guard
            let previousTabInfo = HotKeyManager.shared.getHotKey(
                key: "previous_tab"
            ),
            let nextTabInfo = HotKeyManager.shared.getHotKey(key: "next_tab")
        else {
            return false
        }

        let relevantModifiers: NSEvent.ModifierFlags = [
            .command, .option, .control, .shift,
        ]
        let eventModifiers = event.modifierFlags.intersection(relevantModifiers)

        if previousTabInfo.isEnabled,
           event.keyCode == previousTabInfo.shortcut.keyCode,
           eventModifiers
           == previousTabInfo.shortcut.modifiers.intersection(
               relevantModifiers
           )
        {
            viewModel.selectPreviousChip()
            floatingContentView.headerView.updateChipSelection()
            return true
        }

        if nextTabInfo.isEnabled,
           event.keyCode == nextTabInfo.shortcut.keyCode,
           eventModifiers
           == nextTabInfo.shortcut.modifiers.intersection(
               relevantModifiers
           )
        {
            viewModel.selectNextChip()
            floatingContentView.headerView.updateChipSelection()
            return true
        }

        return false
    }

    // MARK: - Quick Paste

    private func quickPasteIndex(for event: NSEvent) -> Int? {
        guard isQuickPastePressed else { return nil }
        let keyCodes: [UInt16: Int] = [
            KeyCode.one: 0, KeyCode.two: 1, KeyCode.three: 2,
            KeyCode.four: 3, KeyCode.five: 4, KeyCode.six: 5,
            KeyCode.seven: 6, KeyCode.eight: 7, KeyCode.nine: 8,
        ]
        return keyCodes[event.keyCode]
    }

    private func performQuickPaste(at index: Int) {
        let historyView = floatingContentView.historyView
        guard index < historyView.dataList.count else { return }
        historyView.selectAndScrollTo(index: index)
        ClipActionService.shared.paste(
            historyView.dataList[index],
            isAttribute: true
        )
    }
}
