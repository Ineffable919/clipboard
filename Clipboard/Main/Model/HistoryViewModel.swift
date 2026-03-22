import AppKit
import Carbon
import Foundation
import SwiftUI

@MainActor
@Observable final class HistoryViewModel {
    private let pd = PasteDataStore.main
    @ObservationIgnored private weak var env: AppEnvironment?

    var selectedIds: Set<PasteboardModel.ID> = []
    var activeId: PasteboardModel.ID?
    var showPreviewId: PasteboardModel.ID?
    var isQuickPastePressed: Bool = false

    @ObservationIgnored var lastTapId: PasteboardModel.ID?
    @ObservationIgnored var lastTapTime: TimeInterval = 0
    @ObservationIgnored var isDel: Bool = false
    @ObservationIgnored var lastLoadTriggerIndex: Int = -1

    var isMultiSelectMode: Bool {
        selectedIds.count > 1
    }

    func isItemSelected(_ id: PasteboardModel.ID?) -> Bool {
        guard let id else { return false }
        return selectedIds.contains(id)
    }

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

    // MARK: - Selection

    /// 单选：清除旧选中，选中指定项
    func selectSingle(id: PasteboardModel.ID?) {
        selectedIds.removeAll()
        activeId = id
        if let id {
            selectedIds.insert(id)
        }
    }

    /// 切换某项的选中状态（Cmd+点击）
    func toggleSelection(id: PasteboardModel.ID?) {
        guard let id else { return }

        if selectedIds.contains(id) {
            selectedIds.remove(id)
            if activeId == id {
                activeId = selectedIds.first
            }
        } else {
            selectedIds.insert(id)
            activeId = id
        }
    }

    /// 选中前 9 个项目（Cmd+A）
    func selectFirstNine() {
        let count = min(9, pd.dataList.count)
        guard count > 0 else { return }

        selectedIds.removeAll()
        for i in 0 ..< count {
            if let id = pd.dataList[i].id {
                selectedIds.insert(id)
            }
        }
        activeId = pd.dataList[0].id
    }

    var activeIndex: Int? {
        guard let activeId else { return nil }
        return pd.dataList.firstIndex { $0.id == activeId }
    }

    func selectedItems() -> [PasteboardModel] {
        pd.dataList.filter { item in
            guard let id = item.id else { return false }
            return selectedIds.contains(id)
        }
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

    func handleTap(
        on item: PasteboardModel,
        index _: Int,
        isCommandHeld: Bool = false,
        doubleTapAction: () -> Void
    ) {
        guard let env else { return }

        if env.focusView != .history {
            env.focusView = .history
        }

        // Cmd+点击：多选切换
        if isCommandHeld {
            toggleSelection(id: item.id)
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let isSameItem = activeId == item.id

        if isSameItem,
           shouldHandleDoubleTap(
               for: item.id,
               currentTime: now,
               interval: 0.3
           )
        {
            if isMultiSelectMode {
                pasteSelectedItems()
            } else {
                doubleTapAction()
            }
            resetTapState()
            return
        }

        if !isSameItem {
            selectSingle(id: item.id)
        }
        updateTapState(id: item.id, time: now)
    }

    // MARK: - Paste / Copy

    /// 粘贴
    func pasteSelectedItems(
        isAttribute: Bool = true,
        checkPermissions: Bool = false
    ) {
        let items = selectedItems()
        guard !items.isEmpty else { return }

        if items.count == 1 {
            ClipActionService.shared.paste(
                items[0],
                isAttribute: isAttribute,
                checkPermissions: checkPermissions
            )
        } else {
            ClipActionService.shared.pasteMultiple(
                items,
                isAttribute: isAttribute,
                checkPermissions: checkPermissions
            )
        }
    }

    /// 复制
    func copySelectedItems(isAttribute: Bool = true) {
        let items = selectedItems()
        guard !items.isEmpty else { return }

        if items.count == 1 {
            ClipActionService.shared.copy(items[0], isAttribute: isAttribute)
        } else {
            ClipActionService.shared.copyMultiple(
                items,
                isAttribute: isAttribute
            )
        }
    }

    // MARK: - Delete Operations

    func deleteActiveItem() {
        guard let index = activeIndex else { return }
        deleteItem(at: index)
    }

    func deleteItem(at index: Int) {
        guard index < pd.dataList.count else { return }
        let item = pd.dataList[index]

        if let id = item.id {
            selectedIds.remove(id)
        }

        isDel = true

        _ = withAnimation(.easeInOut(duration: 0.2)) {
            pd.dataList.remove(at: index)
        }

        ClipActionService.shared.delete(item)

        let needsMore =
            pd.dataList.count < 50 && pd.hasMoreData && !pd.isLoadingPage

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            isDel = false

            if needsMore {
                pd.loadNextPage()
            }
        }
        updateSelectionAfterDeletion(at: index)
    }

    private func updateSelectionAfterDeletion(at index: Int) {
        if pd.dataList.isEmpty {
            selectSingle(id: nil)
        } else {
            let newIndex = min(index, pd.dataList.count - 1)
            selectSingle(id: pd.dataList[newIndex].id)
        }
    }

    func showDeleteConfirmAlert(
        onConfirm: @escaping () -> Void
    ) {
        guard let env else { return }

        let alert = NSAlert()
        alert.messageText = String(localized: .deleteTitle)
        alert.informativeText = String(localized: .deleteMessage)
        alert.alertStyle = .warning
        alert.addButton(
            withTitle: String(localized: .deleteTitle)
        )
        alert.addButton(withTitle: String(localized: .commonCancel))

        let currentActiveId = activeId

        let handleResponse: (NSApplication.ModalResponse) -> Void = {
            [weak self] response in
            defer {
                env.isShowDel = false
            }

            guard response == .alertFirstButtonReturn,
                  self?.activeId == currentActiveId
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

    func shouldLoadNextPage(at index: Int) -> Bool {
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
              let id = activeId
        else {
            return .none
        }

        if id == first {
            return WindowManager.shared.getCurrentDisplayMode() == .drawer
                ? .trailing : .bottom
        } else if id == last {
            return WindowManager.shared.getCurrentDisplayMode() == .drawer
                ? .leading : .top
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
                selectedIds.removeAll()
                activeId = nil
                showPreviewId = nil
                return
            }

            let firstId = pd.dataList.first?.id

            if isMultiSelectMode {
                let currentIds = Set(pd.dataList.compactMap(\.id))
                let validIds = selectedIds.filter { id in
                    guard let id else { return false }
                    return currentIds.contains(id)
                }
                if !validIds.isEmpty {
                    selectedIds = validIds
                    activeId = firstId
                    showPreviewId = nil
                    Task { @MainActor in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(firstId, anchor: .trailing)
                        }
                    }
                    return
                }
            }

            let needsScrolling = activeId != firstId
            selectSingle(id: firstId)
            showPreviewId = nil

            if !needsScrolling {
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(firstId, anchor: .trailing)
                    }
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
        selectedIds.removeAll()
        activeId = nil
    }
}
