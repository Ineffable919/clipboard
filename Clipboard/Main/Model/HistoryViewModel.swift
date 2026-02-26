import AppKit
import Carbon
import Foundation
import SwiftUI

@MainActor
@Observable final class HistoryViewModel {
    private let pd = PasteDataStore.main
    @ObservationIgnored private weak var env: AppEnvironment?

    var selectedId: PasteboardModel.ID?
    var showPreviewId: PasteboardModel.ID?
    var isQuickPastePressed: Bool = false

    @ObservationIgnored var selectedIndex: Int?
    @ObservationIgnored var lastTapId: PasteboardModel.ID?
    @ObservationIgnored var lastTapTime: TimeInterval = 0
    @ObservationIgnored var isDel: Bool = false
    @ObservationIgnored var lastLoadTriggerIndex: Int = -1

    // MARK: - Configuration

    func configure(env: AppEnvironment) {
        self.env = env
    }

    // MARK: - Search Keyword

    var searchKeyword: String {
        pd.lastDataChangeType == .searchFilter ? pd.currentSearchKeyword : ""
    }

    // MARK: - Quick Paste Index

    func quickPasteIndex(for index: Int) -> Int? {
        guard isQuickPastePressed, index < 9 else { return nil }
        return index + 1
    }

    // MARK: - Tap Handling

    func shouldHandleDoubleTap(
        for itemId: PasteboardModel.ID,
        currentTime: TimeInterval,
        interval: TimeInterval
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

    func setSelection(id: PasteboardModel.ID?, index: Int) {
        selectedId = id
        selectedIndex = index
    }

    func handleTap(
        on item: PasteboardModel,
        index: Int,
        doubleTapAction: () -> Void
    ) {
        guard let env else { return }

        if env.focusView != .history {
            env.focusView = .history
        }

        let now = ProcessInfo.processInfo.systemUptime
        let isSameItem = selectedId == item.id

        if isSameItem,
           shouldHandleDoubleTap(
               for: item.id,
               currentTime: now,
               interval: 0.3
           )
        {
            doubleTapAction()
            resetTapState()
            return
        }

        if !isSameItem {
            setSelection(id: item.id, index: index)
        }
        updateTapState(id: item.id, time: now)
    }

    // MARK: - Delete Operations

    func deleteItem(at index: Int) {
        guard let env, index < pd.dataList.count else { return }
        let item = pd.dataList[index]

        isDel = true

        _ = withAnimation(.easeInOut(duration: 0.2)) {
            pd.dataList.remove(at: index)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            updateSelectionAfterDeletion(at: index)
            isDel = false
        }

        ClipActionService.shared.delete(item)

        if pd.dataList.count < 50,
           pd.hasMoreData,
           !pd.isLoadingPage
        {
            pd.loadNextPage()
        }
    }

    private func updateSelectionAfterDeletion(at index: Int) {
        if pd.dataList.isEmpty {
            setSelection(id: nil, index: 0)
        } else {
            let newIndex = min(index, pd.dataList.count - 1)
            setSelection(
                id: pd.dataList[newIndex].id,
                index: newIndex
            )
        }
    }

    func showDeleteConfirmAlert(
        for index: Int,
        onConfirm: @escaping () -> Void
    ) {
        guard let env else { return }

        let alert = NSAlert()
        alert.messageText = "确认删除吗？"
        alert.informativeText = "删除后无法恢复"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        let handleResponse: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            defer {
                env.isShowDel = false
            }

            guard response == .alertFirstButtonReturn,
                  self?.selectedIndex == index
            else {
                return
            }

            onConfirm()
        }

        let shouldUseSheet: Bool = {
            if #available(macOS 26.0, *) {
                return true
            }
            return WindowManager.shared.getCurrentDisplayMode() == .floating
        }()

        if shouldUseSheet, let window = NSApp.keyWindow {
            alert.beginSheetModal(
                for: window,
                completionHandler: handleResponse
            )
        } else {
            let response = alert.runModal()
            handleResponse(response)
        }
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

        if let index {
            guard shouldUpdateLoadTrigger(triggerIndex: pd.pageIndex) else {
                return
            }
            guard shouldLoadNextPage(at: index) else {
                return
            }
        }

        log.debug(
            "触发滚动加载下一页 (index: \(index ?? -1), dataCount: \(pd.dataList.count))"
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
            return WindowManager.shared.getCurrentDisplayMode() == .drawer ? .trailing : .bottom
        } else if id == last {
            return WindowManager.shared.getCurrentDisplayMode() == .drawer ? .leading : .top
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
                Task { @MainActor in
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

    func cleanup() {
        isDel = false
        isQuickPastePressed = false
        showPreviewId = nil
        selectedIndex = nil
    }
}
