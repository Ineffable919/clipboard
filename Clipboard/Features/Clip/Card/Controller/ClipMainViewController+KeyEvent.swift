//
//  ClipMainViewController+KeyEvent.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import Combine

// MARK: - Keyboard Events

extension ClipMainViewController: NSGestureRecognizerDelegate {
    func gestureRecognizer(
        _: NSGestureRecognizer,
        shouldAttemptToRecognizeWith event: NSEvent
    ) -> Bool {
        guard
            let hitView = view.window?.contentView?
            .hitTest(event.locationInWindow)
        else {
            return true
        }
        if hitView.isDescendant(of: collectionView) {
            return false
        }

        if hitView.isDescendant(of: topBarView) {
            return hitView === topBarView
        }

        if hitView is NSControl {
            return false
        }

        return true
    }
}

extension ClipMainViewController {
    func keyDownEvent(_ event: NSEvent) -> NSEvent? {
        log.info("focusRegion: \(focusRegion),"firstResponder: \String(describing: view.window?.firstResponder)"")
        if focusRegion == .popover {
            if event.keyCode == KeyCode.escape {
                closePreviewPopover()
                return nil
            }
            return event
        }

        if focusRegion == .chipEditing {
            switch event.keyCode {
            case KeyCode.escape:
                topBarView.cancelKeyboardEditing()
                setFocusRegion(.collection)
                view.window?.makeFirstResponder(collectionView)
                return nil
            case KeyCode.return:
                topBarView.commitKeyboardEditing()
                setFocusRegion(.collection)
                view.window?.makeFirstResponder(collectionView)
                return nil
            default:
                return event
            }
        }

        if let index = handleQuickPasteShortcut(event) {
            performQuickPaste(at: index)
            return nil
        }

        if KeyCode.shouldTriggerSearch(for: event),
           !topBarView.searchField.isFirstResponder,
           focusRegion != .search
        {
            if let characters = event.characters, !characters.isEmpty {
                topBarView.activateSearch(with: characters)
            }
            setFocusRegion(.search)
            view.window?.makeFirstResponder(topBarView.searchField)
            return nil
        }

        if handleChipTab(event, viewModel: topVM) {
            return nil
        }

        if event.modifierFlags.contains(.command) {
            return handleCommandKeyEvent(event)
        }

        switch event.keyCode {
        case KeyCode.escape:
            return escapeKeyDown(event)
        case KeyCode.delete:
            return deleteKeyDown(event)
        case KeyCode.return:
            return returnKeyDown(event)
        case KeyCode.space:
            return spaceKeyDown(event)
        default:
            return event
        }
    }

    private func escapeKeyDown(_: NSEvent) -> NSEvent? {
        let field = topBarView.searchField
        if field.isFirstResponder {
            if field.suggestionWindow.isVisible {
                field.suggestionWindow.hide()
                return nil
            }
            if topVM.hasInput {
                field.clearAllContent()
            } else {
                topBarView.deactivateSearch()
                view.window?.makeFirstResponder(collectionView)
                setFocusRegion(.collection)
            }
        } else {
            WindowManager.shared.toggleWindow()
        }
        return nil
    }

    private func spaceKeyDown(_ event: NSEvent) -> NSEvent? {
        guard !topBarView.searchField.isFirstResponder,
              focusRegion != .chipEditing,
              focusRegion == .collection
        else { return event }

        guard selectIndexPath.item < dataList.value.count else { return nil }
        let item = dataList.value[selectIndexPath.item]
        preview(item)
        return nil
    }

    private func deleteKeyDown(_ event: NSEvent) -> NSEvent? {
        guard !topBarView.searchField.isFirstResponder,
              focusRegion != .chipEditing
        else { return event }
        if selectIndexPath.item < dataList.value.count {
            let item = dataList.value[selectIndexPath.item]
            delete(item, indexPath: selectIndexPath)
            return nil
        }
        return event
    }

    private func returnKeyDown(_ event: NSEvent) -> NSEvent? {
        guard focusRegion == .collection else { return event }
        let item = dataList.value[selectIndexPath.item]
        ClipActionService.shared.paste(
            item,
            isAttribute: !hasPlainTextModifier(event),
            checkPermissions: PasteUserDefaults.pasteDirect,
            showTip: !PasteUserDefaults.pasteDirect
        )
        return nil
    }

    private func hasPlainTextModifier(_ event: NSEvent) -> Bool {
        KeyCode.hasModifier(
            event,
            modifierIndex: PasteUserDefaults.plainTextModifier
        )
    }

    private func handleCommandKeyEvent(_ event: NSEvent) -> NSEvent? {
        let hasModifiers = !event.modifierFlags.intersection([
            .option, .control, .shift,
        ]).isEmpty
        guard !hasModifiers else {
            return event
        }

        switch event.keyCode {
        case KeyCode.c:
            return handleCopy()

        case KeyCode.e:
            return handleEdit()

        default:
            return event
        }
    }

    private func handleCopy() -> NSEvent? {
        guard selectIndexPath.item < dataList.value.count else { return nil }
        let item = dataList.value[selectIndexPath.item]
        copy(item)
        return nil
    }

    private func handleEdit() -> NSEvent? {
        guard selectIndexPath.item < dataList.value.count else { return nil }
        let item = dataList.value[selectIndexPath.item]
        edit(item)
        return nil
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
            topBarView.updateChipSelection()
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
            topBarView.updateChipSelection()
            return true
        }

        return false
    }
}
