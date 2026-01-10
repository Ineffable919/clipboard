//
//  HistoryView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import Carbon
import SwiftUI

struct HistoryView: View {
    // MARK: - Properties

    @Environment(AppEnvironment.self) private var env
    @State private var historyVM = HistoryViewModel()
    @FocusState private var isFocused: Bool
    @AppStorage(PrefKey.enableLinkPreview.rawValue)
    private var enableLinkPreview: Bool = PasteUserDefaults.enableLinkPreview
    private let pd = PasteDataStore.main

    @State private var flagsMonitorToken: Any?

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                if pd.dataList.isEmpty {
                    emptyStateView
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        contentView()
                    }
                    .focusable()
                    .focused($isFocused)
                    .focusEffectDisabled()
                    .onChange(of: env.focusView) {
                        isFocused = (env.focusView == .history)
                    }
                    .onChange(of: historyVM.selectedId) { _, newId in
                        if let id = newId {
                            proxy.scrollTo(id, anchor: historyVM.scrollAnchor())
                        }
                    }
                }
                EmptyView()
                    .onChange(of: pd.dataList) {
                        historyVM.reset(proxy: proxy)
                    }
                    .onChange(of: env.quickPasteResetTrigger) {
                        historyVM.isQuickPastePressed = false
                    }
            }
            .onAppear {
                appear()
            }
            .onDisappear {
                disappear()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard env.focusView != .history else { return }
            env.focusView = .history
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Const.space12) {
            if #available(macOS 26.0, *) {
                Image(systemName: "sparkle.text.clipboard")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor.opacity(0.8))
            } else {
                Image("sparkle.text.clipboard")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor.opacity(0.8))
            }

            Text("没有剪贴板历史")
                .foregroundStyle(.secondary)

            Text("复制内容后将显示在这里")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func contentView() -> some View {
        LazyHStack(alignment: .top, spacing: Const.cardSpace) {
            if #available(macOS 26.0, *) {
                ForEach(pd.dataList.enumerated(), id: \.element.id) {
                    index,
                        item in
                    cardViewItem(for: item, at: index)
                }
            } else {
                ForEach(Array(pd.dataList.enumerated()), id: \.element.id) {
                    index,
                        item in
                    cardViewItem(for: item, at: index)
                }
            }
        }
        .padding(.horizontal, Const.cardSpace)
        .padding(.vertical, Const.space4)
    }

    private var searchKeyword: String {
        pd.lastDataChangeType == .searchFilter ? pd.currentSearchKeyword : ""
    }

    private func cardViewItem(for item: PasteboardModel, at index: Int)
        -> some View
    {
        ClipCardView(
            model: item,
            isSelected: historyVM.selectedId == item.id,
            showPreviewId: $historyVM.showPreviewId,
            quickPasteIndex: quickPasteIndex(for: index),
            enableLinkPreview: enableLinkPreview,
            searchKeyword: searchKeyword,
            onRequestDelete: { requestDel(id: item.id) }
        )
        .contentShape(Rectangle())
        .onTapGesture { handleOptimisticTap(on: item, index: index) }
        .onDrag {
            env.draggingItemId = item.id
            historyVM.setSelection(id: item.id, index: index)
            return item.itemProvider()
        }
        .task(id: item.id) {
            guard historyVM.shouldLoadNextPage(at: index) else { return }
            historyVM.loadNextPageIfNeeded(at: index)
        }
    }

    private func quickPasteIndex(for index: Int) -> Int? {
        guard historyVM.isQuickPastePressed, index < 9 else { return nil }
        return index + 1
    }

    private func handleDoubleTap(on item: PasteboardModel) {
        env.actions.paste(
            item,
            isAttribute: true,
        )
    }

    private func handleOptimisticTap(on item: PasteboardModel, index: Int) {
        if env.focusView != .history {
            env.focusView = .history
        }

        let now = ProcessInfo.processInfo.systemUptime
        let isSameItem = historyVM.selectedId == item.id

        if isSameItem, historyVM.shouldHandleDoubleTap(
            for: item.id,
            currentTime: now,
            interval: 0.2
        ) {
            handleDoubleTap(on: item)
            historyVM.resetTapState()
            return
        }

        if !isSameItem {
            historyVM.setSelection(id: item.id, index: index)
        }
        historyVM.updateTapState(id: item.id, time: now)
    }

    private func deleteItem(for id: PasteboardModel.ID) {
        guard let index = pd.dataList.firstIndex(where: { $0.id == id })
        else {
            return
        }

        historyVM.isDel = true

        let item = pd.dataList[index]
        env.actions.delete(item)

        withAnimation(.easeInOut(duration: 0.2)) {
            pd.dataList.remove(at: index)
            updateSelectionAfterDeletion(at: index)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            historyVM.isDel = false

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
            historyVM.setSelection(id: nil, index: 0)
        } else {
            let newIndex = min(index, pd.dataList.count - 1)
            historyVM.setSelection(
                id: pd.dataList[newIndex].id,
                index: newIndex
            )
        }
    }

    private func moveSelection(offset: Int, event _: NSEvent) -> NSEvent? {
        guard !pd.dataList.isEmpty else {
            historyVM.showPreviewId = nil
            historyVM.setSelection(id: nil, index: 0)
            NSSound.beep()
            return nil
        }

        let currentIndex = historyVM.selectedIndex ?? 0
        let newIndex = max(0, min(currentIndex + offset, pd.dataList.count - 1))

        guard newIndex != currentIndex else {
            NSSound.beep()
            return nil
        }

        historyVM.setSelection(id: pd.dataList[newIndex].id, index: newIndex)
        if historyVM.showPreviewId != nil {
            historyVM.showPreviewId = nil
        }

        if offset > 0, historyVM.shouldLoadNextPage(at: newIndex) {
            Task.detached(priority: .userInitiated) { [weak historyVM] in
                await historyVM?.loadNextPageIfNeeded(at: newIndex)
            }
        }
        return nil
    }

    private func appear() {
        EventDispatcher.shared.registerHandler(
            matching: .keyDown,
            key: "history",
            handler: keyDownEvent(_:),
        )

        flagsMonitorToken = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            flagsChangedEvent(event)
        }

        if historyVM.selectedId == nil {
            historyVM.setSelection(id: pd.dataList.first?.id, index: 0)
        }
    }

    private func disappear() {
        if let token = flagsMonitorToken {
            NSEvent.removeMonitor(token)
            flagsMonitorToken = nil
        }
        historyVM.cleanup()
    }

    private func flagsChangedEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window == ClipMainWindowController.shared.window,
              ClipMainWindowController.shared.isVisible
        else {
            return event
        }

        historyVM.isQuickPastePressed = KeyCode.isQuickPasteModifierPressed()
        return event
    }

    private func keyDownEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window == ClipMainWindowController.shared.window
        else {
            return event
        }

        guard env.focusView == .history else {
            return event
        }

        if event.keyCode == KeyCode.escape {
            if case .some(_?) = historyVM.showPreviewId {
                historyVM.showPreviewId = nil
                return nil
            }
            if ClipMainWindowController.shared.isVisible {
                ClipMainWindowController.shared.toggleWindow()
                return nil
            }
            return event
        }

        if let index = HistoryViewModel.handleQuickPasteShortcut(event) {
            performQuickPaste(at: index)
            return nil
        }

        if event.modifierFlags.contains(.command) {
            return handleCommandKeyEvent(event)
        }

        // 检查是否有修饰键（用于 tab 切换功能）
        let hasModifiers = !event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty

        switch event.keyCode {
        case UInt16(kVK_LeftArrow):
            if hasModifiers {
                return event
            }
            return moveSelection(offset: -1, event: event)

        case UInt16(kVK_RightArrow):
            if hasModifiers {
                return event
            }
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

    private func performQuickPaste(at index: Int) {
        guard index >= 0, index < pd.dataList.count else {
            NSSound.beep()
            return
        }

        let item = pd.dataList[index]
        historyVM.setSelection(id: item.id, index: index)
        env.actions.paste(
            item,
            isAttribute: true,
        )
    }

    private func hasPlainTextModifier(_ event: NSEvent) -> Bool {
        KeyCode.hasModifier(
            event,
            modifierIndex: PasteUserDefaults.plainTextModifier,
        )
    }

    private func handleCommandKeyEvent(_ event: NSEvent) -> NSEvent? {
        let hasModifiers = !event.modifierFlags.intersection([.option, .control, .shift]).isEmpty
        guard !hasModifiers else {
            return event
        }

        switch event.keyCode {
        case UInt16(kVK_ANSI_C):
            return handleCopy()

        case UInt16(kVK_ANSI_E):
            return handleEdit()

        default:
            return event
        }
    }

    private func handleEdit() -> NSEvent? {
        guard let index = historyVM.selectedIndex
        else {
            NSSound.beep()
            return nil
        }
        EditWindowController.shared.openWindow(with: pd.dataList[index])
        return nil
    }

    private func handleCopy() -> NSEvent? {
        guard let index = historyVM.selectedIndex
        else {
            NSSound.beep()
            return nil
        }
        env.actions.copy(pd.dataList[index])
        return nil
    }

    private func handleSpace(_: NSEvent) -> NSEvent? {
        if let id = historyVM.selectedId {
            if historyVM.showPreviewId == id {
                historyVM.showPreviewId = nil
            } else {
                historyVM.showPreviewId = id
            }
        }
        return nil
    }

    private func handleReturnKey(_ event: NSEvent) -> NSEvent? {
        guard let index = historyVM.selectedIndex
        else {
            return event
        }
        env.actions.paste(
            pd.dataList[index],
            isAttribute: !hasPlainTextModifier(event),
        )
        return nil
    }

    private func deleteKeyDown(_: NSEvent) -> NSEvent? {
        guard let id = historyVM.selectedId else {
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

        historyVM.pendingDeleteId = id

        env.isShowDel = true
        showDeleteAlert()
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
                self.historyVM.pendingDeleteId = nil
                self.env.isShowDel = false
            }

            guard response == .alertFirstButtonReturn,
                  let id = historyVM.pendingDeleteId
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
