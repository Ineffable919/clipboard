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
    // MARK: - Constants

    private enum Constants {
        static let doubleTapInterval: TimeInterval = 0.2
        static let deleteAnimationDelay: TimeInterval = 0.2
    }

    // MARK: - Properties

    @EnvironmentObject private var env: AppEnvironment
    @State private var historyVM = HistoryViewModel()
    private let pd = PasteDataStore.main

    var body: some View {
        if pd.dataList.isEmpty {
            emptyStateView
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    contentView()
                }
                .onChange(of: historyVM.selectedId) { _, newId in
                    if let id = newId {
                        proxy.scrollTo(id, anchor: historyVM.scrollAnchor())
                    }
                }
                .onChange(of: pd.dataList) {
                    historyVM.reset(proxy: proxy)
                }
            }
            .onAppear {
                appear()
            }
            .onDisappear {
                historyVM.cleanup()
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

    private func cardViewItem(for item: PasteboardModel, at index: Int)
        -> some View
    {
        ClipCardView(
            model: item,
            isSelected: historyVM.selectedId == item.id,
            showPreview: makePreviewBinding(for: item.id),
            quickPasteIndex: historyVM.isQuickPastePressed
                && index < 9
                ? index + 1 : nil,
            onRequestDelete: { requestDel(id: item.id) }
        )
        .onTapGesture { handleOptimisticTap(on: item) }
        .onDrag {
            env.draggingItemId = item.id
            return item.itemProvider()
        }
        .task(id: item.id) {
            if historyVM.shouldLoadNextPage(at: index) {
                historyVM.loadNextPageIfNeeded(at: index)
            }
        }
    }

    private func handleDoubleTap(on item: PasteboardModel) {
        if historyVM.selectedId != item.id {
            historyVM.selectedId = item.id
        }
        env.actions.paste(
            item,
            isAttribute: true
        )
    }

    private func handleOptimisticTap(on item: PasteboardModel) {
        if env.focusView != .history {
            env.focusView = .history
        }

        if historyVM.selectedId != item.id {
            historyVM.selectedId = item.id
        }

        let now = ProcessInfo.processInfo.systemUptime

        if historyVM.shouldHandleDoubleTap(
            for: item.id,
            currentTime: now,
            interval: Constants.doubleTapInterval
        ) {
            handleDoubleTap(on: item)
            historyVM.resetTapState()
        } else {
            historyVM.updateTapState(id: item.id, time: now)
        }
    }

    private func makePreviewBinding(for itemId: PasteboardModel.ID) -> Binding<
        Bool
    > {
        Binding(
            get: { historyVM.showPreviewId == itemId },
            set: { historyVM.showPreviewId = $0 ? itemId : nil },
        )
    }

    private func deleteItem(for id: PasteboardModel.ID) {
        guard
            let index = pd.dataList.firstIndex(where: { $0.id == id }
            )
        else {
            return
        }

        historyVM.isDel = true

        let item = pd.dataList[index]
        env.actions.delete(item)

        withAnimation(.easeOut(duration: Constants.deleteAnimationDelay)) {
            pd.dataList.remove(at: index)
            updateSelectionAfterDeletion(at: index)
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + Constants.deleteAnimationDelay,
        ) {
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
            historyVM.selectedId = nil
        } else {
            let newIndex = min(index, pd.dataList.count - 1)
            historyVM.selectedId = pd.dataList[newIndex].id
        }
    }

    private func moveSelection(offset: Int, event: NSEvent) -> NSEvent? {
        guard env.focusView == .history else { return event }
        let count = pd.dataList.count
        guard count > 0 else {
            historyVM.selectedId = nil
            historyVM.showPreviewId = nil
            NSSound.beep()
            return nil
        }

        let currentIndex =
            historyVM.selectedId.flatMap { id in
                pd.dataList.firstIndex { $0.id == id }
            } ?? 0

        let newIndex = max(0, min(currentIndex + offset, count - 1))

        guard newIndex != currentIndex else {
            NSSound.beep()
            return nil
        }
        let newId = pd.dataList[newIndex].id
        historyVM.selectedId = newId

        if offset > 0, historyVM.shouldLoadNextPage(at: newIndex) {
            historyVM.loadNextPageIfNeeded(at: newIndex)
        }
        return nil
    }

    private func appear() {
        EventDispatcher.shared.registerHandler(
            matching: .keyDown,
            key: "history",
            handler: keyDownEvent(_:),
        )

        EventDispatcher.shared.registerHandler(
            matching: .flagsChanged,
            key: "historyFlags",
            handler: flagsChangedEvent(_:)
        )

        if historyVM.selectedId == nil {
            historyVM.selectedId = pd.dataList.first?.id
        }
    }

    private func flagsChangedEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window == ClipMainWindowController.shared.window,
            env.focusView == .history
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

        if event.keyCode == KeyCode.escape, env.focusView == .history {
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

    private func performQuickPaste(at index: Int) {
        guard index >= 0, index < pd.dataList.count else {
            NSSound.beep()
            return
        }

        let item = pd.dataList[index]
        historyVM.selectedId = item.id
        env.actions.paste(
            item,
            isAttribute: true
        )
    }

    private func hasPlainTextModifier(_ event: NSEvent) -> Bool {
        KeyCode.hasModifier(
            event,
            modifierIndex: PasteUserDefaults.plainTextModifier,
        )
    }

    private func handleCommandKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard env.focusView == .history else {
            return event
        }

        switch event.keyCode {
        case UInt16(kVK_ANSI_C):
            return handleCopyCommand()
        default:
            return event
        }
    }

    private func handleCopyCommand() -> NSEvent? {
        guard let id = historyVM.selectedId,
            let item = pd.dataList.first(where: { $0.id == id })
        else {
            NSSound.beep()
            return nil
        }
        env.actions.copy(item)
        return nil
    }

    private func handleSpace(_ event: NSEvent) -> NSEvent? {
        guard env.focusView == .history else {
            return event
        }
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
        guard env.focusView == .history else { return event }
        guard let id = historyVM.selectedId,
            let item = pd.dataList.first(where: { $0.id == id })
        else {
            return event
        }
        env.actions.paste(
            item,
            isAttribute: !hasPlainTextModifier(event)
        )
        return nil
    }

    private func deleteKeyDown(_ event: NSEvent) -> NSEvent? {
        guard env.focusView == .history else { return event }
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
                    completionHandler: handleResponse
                )
            }
        } else {
            let response = alert.runModal()
            handleResponse(response)
        }
    }
}
