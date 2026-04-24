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
    var scrollPosition = ScrollPosition(idType: PasteboardModel.ID.self)

    @ObservationIgnored var lastTapId: PasteboardModel.ID?
    @ObservationIgnored var lastTapTime: TimeInterval = 0
    @ObservationIgnored var pendingDeleteCount: Int = 0
    @ObservationIgnored var lastLoadTriggerIndex: Int = -1
    @ObservationIgnored private var flagsMonitorToken: Any?

    @ObservationIgnored private var deleteThrottleTask: Task<Void, Never>?
    @ObservationIgnored private var pendingDeleteQueue: [Int] = []
    @ObservationIgnored private var isKeyRepeatDeleting: Bool = false

    var isMultiSelectMode: Bool {
        selectedIds.count > 1
    }

    func isItemSelected(_ id: PasteboardModel.ID?) -> Bool {
        guard let id else { return false }
        return selectedIds.contains(id)
    }

    func isShowPreview(_ id: PasteboardModel.ID?) -> Bool {
        guard let id else { return false }
        return showPreviewId == id
    }

    func togglePreview(for id: PasteboardModel.ID?) {
        if showPreviewId == id {
            showPreviewId = nil
        } else {
            showPreviewId = id
        }
    }

    func closePreview() {
        showPreviewId = nil
    }

    // MARK: - Configuration

    func configure(env: AppEnvironment) {
        self.env = env
    }

    // MARK: - Search Keyword

    var searchKeyword: String {
        (pd.lastDataChangeType == .loadMore
            || pd.lastDataChangeType == .searchFilter)
            ? pd.currentSearchKeyword
            : ""
    }

    // MARK: - Quick Paste Index

    func quickPasteIndex(for index: Int) -> Int? {
        guard isQuickPastePressed, index < 9 else { return nil }
        return index + 1
    }

    // MARK: - Selection

    /// 单选：清除旧选中，选中指定项
    func selectSingle(id: PasteboardModel.ID?, animate: Bool = true) {
        selectedIds.removeAll()
        activeId = id
        if let id {
            selectedIds.insert(id)
            if animate {
                scrollPosition.scrollTo(
                    id: id,
                    anchor: scrollAnchor()
                )
            }
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
        guard !selectedIds.isEmpty else { return [] }
        if selectedIds.count == 1, let activeId,
           let item = pd.dataList.first(where: { $0.id == activeId })
        {
            return [item]
        }
        return pd.dataList.filter { item in
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

    /// 卡片点击
    func handleOptimisticTap(on item: PasteboardModel, index: Int) {
        let isCommandHeld = NSEvent.modifierFlags.contains(.command)
        handleTap(
            on: item,
            index: index,
            isCommandHeld: isCommandHeld
        ) {
            self.pasteSelectedItems(
                checkPermissions: PasteUserDefaults.pasteDirect
            )
        }
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

        pendingDeleteCount += 1

        // 连续删除时使用更短更轻的动画，避免动画堆积
        let animation: Animation = isKeyRepeatDeleting
            ? .easeOut(duration: 0.1)
            : .easeInOut(duration: 0.18)

        withAnimation(animation) {
            pd.remove(at: index)
        }

        delete(item)

        updateSelectionAfterDeletion(at: index)

        let needsMore =
            pd.dataList.count < 50 && pd.hasMoreData && !pd.isLoadingPage

        Task { @MainActor in
            pendingDeleteCount -= 1

            if needsMore, pendingDeleteCount == 0 {
                pd.loadNextPage()
            }
        }
    }

    private func delete(_ item: PasteboardModel) {
        guard let id = item.id else { return }

        let isInGroup = CategoryChipStore.shared.selectedChipId != -1

        if isInGroup {
            if item.hidden {
                pd.delete(id: id)
            } else {
                pd.updateItemGroup(itemId: id, groupId: -1)
            }
        } else if item.group != -1 {
            pd.updateItemHidden(itemId: id, hidden: true)
        } else {
            pd.delete(id: id)
        }
    }

    private func updateSelectionAfterDeletion(at index: Int) {
        if pd.dataList.isEmpty {
            selectSingle(id: nil, animate: false)
        } else {
            let newIndex = min(index, pd.dataList.count - 1)
            selectSingle(id: pd.dataList[newIndex].id, animate: false)
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

        let shouldUseSheet: Bool = {
            if #available(macOS 26.0, *) {
                return true
            }
            return WindowManager.shared.getCurrentDisplayMode() == .floating
        }()

        Task { @MainActor in
            defer { env.isShowDel = false }

            let response: NSApplication.ModalResponse =
                if shouldUseSheet, let window = NSApp.keyWindow {
                    await alert.beginSheetModal(for: window)
                } else {
                    alert.runModal()
                }

            guard response == .alertFirstButtonReturn,
                  activeId == currentActiveId
            else {
                return
            }

            onConfirm()
        }
    }

    func requestDelete(at index: Int? = nil) {
        let targetIndex = index ?? activeIndex
        guard let targetIndex else { return }

        guard PasteUserDefaults.delConfirm else {
            deleteItem(at: targetIndex)
            return
        }
        env?.isShowDel = true
        showDeleteConfirmAlert {
            self.deleteItem(at: targetIndex)
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

    func reset() {
        guard pendingDeleteCount == 0 else { return }

        let changeType = pd.lastDataChangeType

        guard changeType != .loadMore else { return }

        lastLoadTriggerIndex = -1

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
                        scrollPosition.scrollTo(
                            id: firstId,
                            anchor: .trailing
                        )
                    }
                }
                return
            }
        }

        selectSingle(id: firstId)
        showPreviewId = nil

        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.25)) {
                scrollPosition.scrollTo(id: firstId, anchor: .trailing)
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

    // MARK: - Lifecycle

    func onAppear(env: AppEnvironment) {
        configure(env: env)
        registerKeyHandler()
        startFlagsMonitor()

        if activeId == nil {
            selectSingle(id: pd.dataList.first?.id)
        }
    }

    func onDisappear() {
        stopFlagsMonitor()
        cleanup()
    }

    func cleanup() {
        pendingDeleteCount = 0
        isQuickPastePressed = false
        isKeyRepeatDeleting = false
        deleteThrottleTask?.cancel()
        deleteThrottleTask = nil
        showPreviewId = nil
        selectedIds.removeAll()
        activeId = nil
    }

    func handleModeSwitch() {
        cleanup()
        pd.resetToDefault()
        selectSingle(id: pd.dataList.first?.id)
    }

    // MARK: - Event Monitor Management

    private func registerKeyHandler() {
        EventDispatcher.shared.registerHandler(
            matching: .keyDown,
            key: "history",
            handler: handleKeyDown(_:)
        )
    }

    private func startFlagsMonitor() {
        flagsMonitorToken = NSEvent.addLocalMonitorForEvents(
            matching: .flagsChanged
        ) { [weak self] event in
            self?.handleFlagsChanged(event) ?? event
        }
    }

    private func stopFlagsMonitor() {
        if let token = flagsMonitorToken {
            NSEvent.removeMonitor(token)
            flagsMonitorToken = nil
        }
    }

    // MARK: - Keyboard Event Handling

    private func handleFlagsChanged(_ event: NSEvent) -> NSEvent? {
        guard event.window == ClipMainWindowController.shared.window,
              ClipMainWindowController.shared.isVisible
        else {
            return event
        }

        isQuickPastePressed = KeyCode.isQuickPasteModifierPressed()
        return event
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard event.window == ClipMainWindowController.shared.window else {
            return event
        }

        guard env?.focusView == .history else {
            return event
        }

        if event.keyCode == KeyCode.escape {
            return handleEscape(event)
        }

        if let index = Self.handleQuickPasteShortcut(event) {
            performQuickPaste(at: index)
            return nil
        }

        if event.modifierFlags.contains(.command) {
            return handleCommandKey(event)
        }

        let hasModifiers = !event.modifierFlags
            .intersection([.command, .option, .control, .shift])
            .isEmpty

        switch event.keyCode {
        case KeyCode.leftArrow:
            return hasModifiers ? event : moveSelection(offset: -1)

        case KeyCode.rightArrow:
            return hasModifiers ? event : moveSelection(offset: 1)

        case KeyCode.space:
            return handleSpace()

        case KeyCode.return:
            return handleReturn(event)

        case KeyCode.delete, UInt16(kVK_ForwardDelete):
            return handleDelete()

        default:
            return event
        }
    }

    private func handleEscape(_ event: NSEvent) -> NSEvent? {
        if case .some(_?) = showPreviewId {
            showPreviewId = nil
            return nil
        }
        if ClipMainWindowController.shared.isVisible {
            ClipMainWindowController.shared.toggleWindow()
            return nil
        }
        return event
    }

    private func handleCommandKey(_ event: NSEvent) -> NSEvent? {
        let hasOtherModifiers = !event.modifierFlags
            .intersection([.option, .control, .shift])
            .isEmpty
        guard !hasOtherModifiers else { return event }

        switch event.keyCode {
        case KeyCode.c:
            copySelectedItems()
            return nil

        case KeyCode.e:
            openEditWindow()
            return nil

        case KeyCode.a:
            selectFirstNine()
            return nil

        default:
            return event
        }
    }

    private func moveSelection(offset: Int) -> NSEvent? {
        guard !pd.dataList.isEmpty else {
            showPreviewId = nil
            selectSingle(id: nil)
            NSSound.beep()
            return nil
        }

        let currentIndex = activeIndex ?? 0
        let newIndex = max(0, min(currentIndex + offset, pd.dataList.count - 1))

        guard newIndex != currentIndex else {
            NSSound.beep()
            return nil
        }

        selectSingle(id: pd.dataList[newIndex].id)
        if showPreviewId != nil {
            showPreviewId = nil
        }

        if offset > 0, shouldLoadNextPage(at: newIndex) {
            Task(priority: .userInitiated) { [weak self] in
                self?.loadNextPageIfNeeded(at: newIndex)
            }
        }
        return nil
    }

    private func handleSpace() -> NSEvent? {
        if let id = activeId {
            showPreviewId = (showPreviewId == id) ? nil : id
        }
        return nil
    }

    private func handleReturn(_ event: NSEvent) -> NSEvent? {
        guard !selectedIds.isEmpty else { return event }
        let isPlainText = KeyCode.hasModifier(
            event,
            modifierIndex: PasteUserDefaults.plainTextModifier
        )
        pasteSelectedItems(
            isAttribute: !isPlainText,
            checkPermissions: true
        )
        return nil
    }

    private func handleDelete() -> NSEvent? {
        guard activeIndex != nil else {
            NSSound.beep()
            return nil
        }

        if PasteUserDefaults.delConfirm {
            requestDelete()
            return nil
        }

        if event_isARepeat() {
            isKeyRepeatDeleting = true
            scheduleThrottledDelete()
        } else {
            isKeyRepeatDeleting = false
            requestDelete()
        }

        return nil
    }

    /// 键盘长按时的节流删除：合并快速重复的按键事件
    private func scheduleThrottledDelete() {
        guard deleteThrottleTask == nil else { return }

        deleteThrottleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))

            guard !Task.isCancelled else {
                deleteThrottleTask = nil
                return
            }

            if let idx = activeIndex, idx < pd.dataList.count {
                deleteItem(at: idx)
            }

            deleteThrottleTask = nil
        }
    }

    /// 检测当前是否处于键盘重复按键状态
    private func event_isARepeat() -> Bool {
        NSApp.currentEvent?.isARepeat ?? false
    }

    private func performQuickPaste(at index: Int) {
        guard index >= 0, index < pd.dataList.count else {
            NSSound.beep()
            return
        }

        let item = pd.dataList[index]
        selectSingle(id: item.id)
        ClipActionService.shared.paste(
            item,
            isAttribute: true,
            checkPermissions: PasteUserDefaults.pasteDirect
        )
    }

    private func openEditWindow() {
        guard let index = activeIndex else {
            NSSound.beep()
            return
        }
        EditWindowController.shared.openWindow(with: pd.dataList[index])
    }
}
