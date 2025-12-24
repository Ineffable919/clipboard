import AppKit
import Carbon
import Foundation
import SwiftUI

@Observable
final class HistoryViewModel {
    private let pd = PasteDataStore.main
    var selectedId: PasteboardModel.ID?
    var selectedIndex: Int?
    var lastTapId: PasteboardModel.ID?
    var lastTapTime: TimeInterval = 0
    var pendingDeleteId: PasteboardModel.ID?

    var showPreviewId: PasteboardModel.ID?
    var isDel: Bool = false
    var isQuickPastePressed: Bool = false
    var lastLoadTriggerIndex: Int = -1

    // MARK: - Tap Handling

    func shouldHandleDoubleTap(
        for itemId: PasteboardModel.ID,
        currentTime: TimeInterval,
        interval: TimeInterval,
    ) -> Bool {
        guard let lastId = lastTapId else { return false }
        return lastId == itemId && currentTime - lastTapTime <= interval
    }

    func resetTapState() {
        lastTapId = nil
        lastTapTime = 0
    }

    func updateTapState(id: PasteboardModel.ID, time: TimeInterval) {
        lastTapId = id
        lastTapTime = time
    }

    func setSelection(id: PasteboardModel.ID, index: Int) {
        selectedId = id
        selectedIndex = index
    }

    // MARK: - Pagination

    func shouldLoadNextPage(at index: Int)
        -> Bool
    {
        guard pd.hasMoreData else { return false }
        let triggerIndex = pd.dataList.count - 5
        return index >= triggerIndex
    }

    func shouldUpdateLoadTrigger(triggerIndex: Int) -> Bool {
        guard lastLoadTriggerIndex != triggerIndex else { return false }
        lastLoadTriggerIndex = triggerIndex
        return true
    }

    func loadNextPageIfNeeded(at index: Int? = nil) {
        guard pd.dataList.count < pd.totalCount else {
            return
        }
        guard !pd.isLoadingPage else { return }

        if index != nil {
            let triggerIndex = pd.dataList.count - 5
            guard shouldUpdateLoadTrigger(triggerIndex: triggerIndex)
            else {
                return
            }
        }

        log.debug(
            "触发滚动加载下一页 (index: \(index ?? -1), dataCount: \(pd.dataList.count))",
        )
        pd.loadNextPage()
    }

    // MARK: - Scroll Anchor

    func scrollAnchor() -> UnitPoint? {
        guard let first = pd.dataList.first?.id,
              let last = pd.dataList.last?.id,
              let id = selectedId
        else {
            return .none
        }

        if id == first {
            return .trailing
        } else if id == last {
            return .leading
        } else {
            return .none
        }
    }

    func reset(proxy: ScrollViewProxy) {
        guard !isDel else { return }
        lastLoadTriggerIndex = -1
        let changeType = pd.lastDataChangeType
        if changeType == .searchFilter || changeType == .reset {
            if pd.dataList.isEmpty {
                selectedId = nil
                selectedIndex = nil
                showPreviewId = nil
                return
            }

            let firstId = pd.dataList.first?.id
            let needsScrolling = selectedId != firstId
            selectedId = firstId
            selectedIndex = 0
            showPreviewId = nil

            if !needsScrolling {
                DispatchQueue.main.async {
                    proxy.scrollTo(firstId, anchor: .trailing)
                }
            }
        }
    }

    // MARK: - Quick Paste

    static func handleQuickPasteShortcut(_ event: NSEvent) -> Int? {
        guard
            KeyCode.hasModifier(
                event,
                modifierIndex: PasteUserDefaults.quickPasteModifier,
            )
        else {
            return nil
        }

        let quickPasteModifier = KeyCode.modifierFlags(
            from: PasteUserDefaults.quickPasteModifier,
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

    func cleanup() {
        isDel = false
        isQuickPastePressed = false
        showPreviewId = nil
        selectedIndex = nil
    }
}
