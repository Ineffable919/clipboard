//
//  ClipMainViewController+QuickPaste.swift
//  Clipboard
//
//  Created by crown on 2026/4/18.
//

import AppKit
import Carbon
import Combine

// MARK: - Quick Paste

extension ClipMainViewController {
    func flagsChangedEvent(_ event: NSEvent) -> NSEvent? {
        guard collectionView.isFirstResponder
        else {
            return event
        }

        isQuickPastePressed = KeyCode.isQuickPasteModifierPressed()
        return event
    }

    func updateQuickPasteDisplay() {
        let visibleItems = collectionView.visibleItems()
        for case let item as CollectionViewItem in visibleItems {
            guard let indexPath = collectionView.indexPath(for: item) else {
                continue
            }
            item.quickPasteIndex = quickPasteIndex(for: indexPath.item)
        }
    }

    func quickPasteIndex(for index: Int) -> Int? {
        guard isQuickPastePressed, index < 9 else { return nil }
        return index + 1
    }

    func handleQuickPasteShortcut(_ event: NSEvent) -> Int? {
        guard
            KeyCode.hasModifier(
                event,
                modifierIndex: PasteUserDefaults.quickPasteModifier
            )
        else {
            return nil
        }

        let quickPasteModifier = KeyCode.modifierFlags(
            from: PasteUserDefaults.quickPasteModifier
        )
        let otherModifiers = event.modifierFlags.subtracting(quickPasteModifier)
            .intersection([.command, .option, .control])

        guard otherModifiers.isEmpty else {
            return nil
        }

        let numberKeyCodes: [UInt16: Int] = [
            UInt16(kVK_ANSI_1): 0,
            UInt16(kVK_ANSI_2): 1,
            UInt16(kVK_ANSI_3): 2,
            UInt16(kVK_ANSI_4): 3,
            UInt16(kVK_ANSI_5): 4,
            UInt16(kVK_ANSI_6): 5,
            UInt16(kVK_ANSI_7): 6,
            UInt16(kVK_ANSI_8): 7,
            UInt16(kVK_ANSI_9): 8,
        ]

        return numberKeyCodes[event.keyCode]
    }

    func performQuickPaste(at index: Int) {
        guard index >= 0, index < dataList.value.count else {
            NSSound.beep()
            return
        }

        let item = dataList.value[index]
        selectIndexPath = IndexPath(item: index, section: 0)
        collectionView.selectItems(
            at: [selectIndexPath],
            scrollPosition: .centeredHorizontally
        )
        updateSelectedItemBorder()

        if ClipActionService.shared.paste(
            item,
            isAttribute: true,
            checkPermissions: PasteUserDefaults.pasteDirect
        ) {
            resetSelectIndex()
        }
    }
}
