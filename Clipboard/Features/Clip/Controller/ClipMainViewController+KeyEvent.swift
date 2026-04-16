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
    func gestureRecognizer(_: NSGestureRecognizer,
                           shouldAttemptToRecognizeWith event: NSEvent) -> Bool
    {
        guard let hitView = view.window?.contentView?
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

        return true
    }
}

extension ClipMainViewController {
    func keyDownEvent(_ event: NSEvent) -> NSEvent? {
        if KeyCode.shouldTriggerSearch(for: event), !topBarView.searchField.isFirstResponder {
            if let characters = event.characters, !characters.isEmpty {
                topBarView.activateSearch(with: characters)
            } else {
                setFocusRegion(.search)
                view.window?.makeFirstResponder(topBarView.searchField)
            }
            return nil
        }

        switch event.keyCode {
        case KeyCode.escape:
            return escapeKeyDown(event)
        case KeyCode.delete:
            return deleteKeyDown(event)
        case KeyCode.return:
            return returnKeyDown(event)
        default:
            return event
        }
    }

    private func escapeKeyDown(_: NSEvent) -> NSEvent? {
        let field = topBarView.searchField
        if field.isFirstResponder {
            if !field.text.isEmpty {
                field.stringValue = ""
                field.notifyTextChanged("")
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

    private func deleteKeyDown(_ event: NSEvent) -> NSEvent? {
        guard !topBarView.searchField.isFirstResponder else { return event }
        if selectIndexPath.item < dataList.value.count {
            let item = dataList.value[selectIndexPath.item]
            delete(item, indexPath: selectIndexPath)
            return nil
        }
        return event
    }

    private func returnKeyDown(_ event: NSEvent) -> NSEvent? {
        let item = dataList.value[selectIndexPath.item]
        if event.modifierFlags.contains(.shift) {
            pastePlain(item)
        } else {
            paste(item)
        }
        return nil
    }
}
