//
//  HistoryAreaView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers

struct HistoryAreaView: View {
    // MARK: - Constants

    private enum Constants {
        static let doubleTapInterval: TimeInterval = 0.2
        static let deleteAnimationDelay: TimeInterval = 0.2
    }

    // MARK: - Selection State

    private struct SelectionState {
        var selectedId: PasteboardModel.ID?
        var lastTapId: PasteboardModel.ID?
        var lastTapTime: TimeInterval = 0
        var pendingDeleteId: PasteboardModel.ID?
    }

    // MARK: - Properties

    let vm = ClipboardViewModel.shard
    var pd: PasteDataStore
    @State private var selectionState = SelectionState()
    @State private var showPreviewId: PasteboardModel.ID?
    @State private var isDel: Bool = false
    @State private var isQuickPastePressed: Bool = false
    @State private var lastLoadTriggerIndex: Int = -1

    var body: some View {
        if pd.dataList.isEmpty {
            emptyStateView
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    contentView(proxy: proxy)
                }
                .onChange(of: selectionState.selectedId, initial: false) {
                    scrollToSelectedId(proxy: proxy)
                }
                .onChange(of: pd.dataList) {
                    guard !isDel else { return }
                    lastLoadTriggerIndex = -1
                    let changeType = pd.lastDataChangeType
                    if changeType == .searchFilter || changeType == .reset {
                        reset(proxy: proxy)
                    }
                }
            }
            .onAppear {
                appear()
            }
            .onDisappear {
                cleanup()
            }
        }
    }

    private var emptyStateView: some View {
        GeometryReader { geo in
            HStack(alignment: .center) {
                VStack(alignment: .center, spacing: 12) {
                    if #available(macOS 26.0, *) {
                        Image(systemName: "sparkle.text.clipboard")
                            .font(.system(size: 64))
                            .foregroundColor(.accentColor.opacity(0.8))
                    } else {
                        Image("sparkle.text.clipboard")
                            .font(.system(size: 64))
                            .foregroundColor(.accentColor.opacity(0.8))
                    }

                    Text("没有剪贴板历史")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text("复制内容后将显示在这里")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .frame(
                width: geo.size.width,
                height: geo.size.height,
            )
        }
    }

    private func contentView(proxy _: ScrollViewProxy) -> some View {
        LazyHStack(alignment: .top, spacing: Const.cardSpace) {
            ForEach(Array(pd.dataList.enumerated()), id: \.element.id) {
                index, item in
                ClipCardView(
                    model: item,
                    isSelected: selectionState.selectedId == item.id,
                    showPreview: makePreviewBinding(for: item.id),
                    quickPasteIndex: isQuickPastePressed && index < 9
                        ? index + 1 : nil,
                    onRequestDelete: { requestDel(id: item.id) },
                )
                .onTapGesture { handleOptimisticTap(on: item) }
                .onDrag {
                    item.itemProvider()
                }
                .task(id: item.id) {
                    if shouldLoadNextPage(at: index) {
                        loadNextPageIfNeeded(at: index)
                    }
                }
            }
        }
        .padding(.horizontal, Const.cardSpace)
        .padding(.vertical, 4)
    }

    private func handleDoubleTap(on item: PasteboardModel) {
        if selectionState.selectedId != item.id {
            selectionState.selectedId = item.id
        }
        vm.pasteAction(item: item)
    }

    private func handleOptimisticTap(on item: PasteboardModel) {
        if vm.focusView != .history {
            vm.focusView = .history
        }

        if selectionState.selectedId != item.id {
            selectionState.selectedId = item.id
        }

        let now = ProcessInfo.processInfo.systemUptime

        if let lastId = selectionState.lastTapId,
           lastId == item.id,
           now - selectionState.lastTapTime <= Constants.doubleTapInterval
        {
            handleDoubleTap(on: item)
            resetTapState()
        } else {
            updateTapState(id: item.id, time: now)
        }
    }

    // MARK: - Pagination

    private func shouldLoadNextPage(at index: Int) -> Bool {
        guard pd.hasMoreData else { return false }
        let triggerIndex = pd.dataList.count - 5
        return index >= triggerIndex
    }

    private func loadNextPageIfNeeded(at index: Int? = nil) {
        guard pd.dataList.count < pd.totalCount else { return }
        guard !pd.isLoadingPage else { return }

        if index != nil {
            let triggerIndex = pd.dataList.count - 5
            guard lastLoadTriggerIndex != triggerIndex else {
                return
            }
            lastLoadTriggerIndex = triggerIndex
        }

        log.debug(
            "触发滚动加载下一页 (index: \(index ?? -1), dataCount: \(pd.dataList.count))",
        )
        pd.loadNextPage()
    }

    private func resetTapState() {
        selectionState.lastTapId = nil
        selectionState.lastTapTime = 0
    }

    private func updateTapState(id: PasteboardModel.ID, time: TimeInterval) {
        selectionState.lastTapId = id
        selectionState.lastTapTime = time
    }

    private func makePreviewBinding(for itemId: PasteboardModel.ID) -> Binding<
        Bool
    > {
        Binding(
            get: { showPreviewId == itemId },
            set: { showPreviewId = $0 ? itemId : nil },
        )
    }

    private func deleteItem(for id: PasteboardModel.ID) {
        guard let index = pd.dataList.firstIndex(where: { $0.id == id }) else {
            return
        }

        isDel = true

        let item = pd.dataList[index]
        vm.deleteAction(item: item)

        withAnimation(.easeOut(duration: Constants.deleteAnimationDelay)) {
            pd.dataList.remove(at: index)
            updateSelectionAfterDeletion(at: index)
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + Constants.deleteAnimationDelay,
        ) {
            isDel = false

            if pd.dataList.count < 50,
               pd.hasMoreData,
               !pd.isLoadingPage
            {
                pd.loadNextPage()
            }
        }
    }

    private func updateSelectionAfterDeletion(at index: Int) {
        if pd.dataList.isEmpty {
            selectionState.selectedId = nil
        } else {
            let newIndex = min(index, pd.dataList.count - 1)
            selectionState.selectedId = pd.dataList[newIndex].id
        }
    }

    private func scrollToSelectedId(proxy: ScrollViewProxy) {
        guard let id = selectionState.selectedId else { return }
        guard let first = pd.dataList.first?.id,
              let last = pd.dataList.last?.id
        else {
            return
        }

        DispatchQueue.main.async {
            if id == first {
                proxy.scrollTo(id, anchor: .trailing)
            } else if id == last {
                proxy.scrollTo(id, anchor: .leading)
            } else {
                proxy.scrollTo(id)
            }
        }
    }

    private func moveSelection(offset: Int, event: NSEvent) -> NSEvent? {
        guard vm.focusView == .history else { return event }
        let count = pd.dataList.count
        guard count > 0 else {
            selectionState.selectedId = nil
            showPreviewId = nil
            NSSound.beep()
            return nil
        }

        let currentIndex =
            selectionState.selectedId.flatMap { id in
                pd.dataList.firstIndex { $0.id == id }
            } ?? 0

        let newIndex = max(0, min(currentIndex + offset, count - 1))

        guard newIndex != currentIndex else {
            NSSound.beep()
            return nil
        }
        let newId = pd.dataList[newIndex].id
        selectionState.selectedId = newId

        if offset > 0, shouldLoadNextPage(at: newIndex) {
            loadNextPageIfNeeded(at: newIndex)
        }
        return nil
    }

    private func appear() {
        EventDispatcher.shared.registerHandler(
            matching: .keyDown,
            key: "history",
            priority: 100,
            handler: keyDownEvent(_:),
        )

        EventDispatcher.shared.registerHandler(
            matching: .flagsChanged,
            key: "historyFlags",
            handler: flagsChangedEvent(_:)
        )

        if selectionState.selectedId == nil {
            selectionState.selectedId = pd.dataList.first?.id
        }
    }

    private func cleanup() {
        isDel = false
        isQuickPastePressed = false
    }

    private func flagsChangedEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window == ClipMainWindowController.shared.window,
              vm.focusView == .history
        else {
            return event
        }
        isQuickPastePressed = KeyCode.isQuickPasteModifierPressed()
        return event
    }

    private func keyDownEvent(_ event: NSEvent) -> NSEvent? {
        if vm.focusView == .popover {
            if event.modifierFlags.contains(.command),
               event.keyCode == UInt16(kVK_ANSI_C)
            {
                if let window = event.window,
                   let textView = window.firstResponder as? NSTextView
                {
                    let selectedRange = textView.selectedRange()
                    if selectedRange.length > 0 {
                        textView.copy(nil)
                        return nil
                    }
                }
            }
            return event
        }

        guard event.window == ClipMainWindowController.shared.window
        else {
            return event
        }

        if event.keyCode == KeyCode.escape {
            handleEscapeKeyEvent()
            return nil
        }

        if vm.isEditingChip || vm.editingNewChip {
            return event
        }

        if let index = handleQuickPasteShortcut(event) {
            performQuickPaste(at: index)
            return nil
        }

        if KeyCode.shouldTriggerSearch(for: event),
           vm.focusView != .search
        {
            vm.focusView = .search
            return nil
        }

        if event.modifierFlags.contains(.command) {
            return handleCommandKeyEvent(event)
        }

        switch event.keyCode {
        case UInt16(kVK_LeftArrow):
            return moveSelection(offset: -1, event: event)

        case UInt16(kVK_RightArrow):
            return moveSelection(offset: 1, event: event)

        case UInt16(kVK_Space):
            return handleSpace(event)

        case UInt16(kVK_Return):
            return handleReturnKey(event)

        case UInt16(kVK_Delete), UInt16(kVK_ForwardDelete):
            return deleteKeyDown(event)

        default:
            return event
        }
    }

    /// 处理快速粘贴快捷键
    /// - Parameter event: 键盘事件
    /// - Returns: 如果匹配快速粘贴快捷键，返回对应的索引（0-8），否则返回 nil
    private func handleQuickPasteShortcut(_ event: NSEvent) -> Int? {
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

    private func performQuickPaste(at index: Int) {
        guard index >= 0, index < pd.dataList.count else {
            NSSound.beep()
            return
        }

        let item = pd.dataList[index]
        selectionState.selectedId = item.id
        vm.pasteAction(item: item)
    }

    private func hasPlainTextModifier(_ event: NSEvent) -> Bool {
        KeyCode.hasModifier(
            event,
            modifierIndex: PasteUserDefaults.plainTextModifier,
        )
    }

    private func handleCommandKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard vm.focusView == .history else {
            return event
        }

        switch event.keyCode {
        case UInt16(kVK_ANSI_C):
            handleCopyCommand()
            return nil
        default:
            return event
        }
    }

    private func handleCopyCommand() {
        guard let id = selectionState.selectedId,
              let item = pd.dataList.first(where: { $0.id == id })
        else {
            NSSound.beep()
            return
        }
        vm.copyAction(item: item)
    }

    private func handleEscapeKeyEvent() {
        if vm.isEditingChip {
            vm.cancelEditingChip()
        } else if vm.editingNewChip {
            vm.commitNewChipOrCancel(commitIfNonEmpty: false)
        } else if vm.focusView == .search {
            vm.query = ""
            vm.focusView = .history
        } else {
            escapeKeyDown()
        }
    }

    private func escapeKeyDown() {
        if vm.focusView == .search {
            if !vm.query.isEmpty {
                vm.query = ""
            } else {
                vm.focusView = .history
            }
        } else {
            ClipMainWindowController.shared.toggleWindow()
        }
    }

    private func handleSpace(_ event: NSEvent) -> NSEvent? {
        guard vm.focusView == .history else {
            return event
        }
        if let id = selectionState.selectedId {
            if showPreviewId == id {
                showPreviewId = nil
            } else {
                showPreviewId = id
            }
        }
        return nil
    }

    private func handleReturnKey(_ event: NSEvent) -> NSEvent? {
        guard vm.focusView == .history else { return event }
        guard let id = selectionState.selectedId,
              let item = pd.dataList.first(where: { $0.id == id })
        else {
            return event
        }
        vm.pasteAction(item: item, isAttribute: !hasPlainTextModifier(event))
        return nil
    }

    private func deleteKeyDown(_ event: NSEvent) -> NSEvent? {
        guard vm.focusView == .history else { return event }
        guard let id = selectionState.selectedId else {
            NSSound.beep()
            return nil
        }
        requestDel(id: id)
        return nil
    }

    private func requestDel(id: PasteboardModel.ID) {
        guard PasteUserDefaults.delConfirm else {
            deleteItem(for: id)
            return
        }

        selectionState.pendingDeleteId = id

        vm.isShowDel = true
        showDeleteAlert()
    }

    private func reset(proxy: ScrollViewProxy) {
        if pd.dataList.isEmpty {
            selectionState.selectedId = nil
            showPreviewId = nil
            return
        }
        let firstId = pd.dataList.first?.id
        let needsScrolling = selectionState.selectedId != firstId
        selectionState.selectedId = firstId
        showPreviewId = nil

        if !needsScrolling {
            DispatchQueue.main.async {
                proxy.scrollTo(firstId, anchor: .trailing)
            }
        }
    }

    private func showDeleteAlert() {
        let alert = NSAlert()
        alert.messageText = "确认删除吗？"
        alert.informativeText = "删除后无法恢复"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        let handleResponse: (NSApplication.ModalResponse) -> Void = {
            [self] response in
            defer {
                self.selectionState.pendingDeleteId = nil
                self.vm.isShowDel = false
            }

            guard response == .alertFirstButtonReturn,
                  let id = selectionState.pendingDeleteId
            else {
                return
            }

            deleteItem(for: id)
        }

        if #available(macOS 26.0, *) {
            if let window = NSApp.keyWindow {
                alert.beginSheetModal(
                    for: window,
                    completionHandler: handleResponse,
                )
            }
        } else {
            let response = alert.runModal()
            handleResponse(response)
        }
    }
}
