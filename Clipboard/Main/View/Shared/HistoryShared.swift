//
//  HistoryShared.swift
//  Clipboard
//
//  Created by crown on 2026/1/15.
//

import SwiftUI

// MARK: - Empty State View

struct ClipboardEmptyStateView: View {
    enum Style {
        case main
        case floating
    }

    let style: Style

    private var iconSize: CGFloat {
        style == .main ? 64 : 48
    }

    private var iconOpacity: Double {
        style == .main ? 0.8 : 0.6
    }

    var body: some View {
        VStack(spacing: Const.space12) {
            clipboardIcon
                .font(.system(size: iconSize))
                .foregroundStyle(Color.accentColor.opacity(iconOpacity))

            Text("没有剪贴板历史")
                .font(style == .floating ? .system(size: 15, weight: .medium) : .body)
                .foregroundStyle(.secondary)

            Text("复制内容后将显示在这里")
                .font(style == .floating ? .system(size: 13) : .callout)
                .foregroundStyle(style == .floating ? .tertiary : .secondary)
        }
        .padding(style == .main ? .all : [])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var clipboardIcon: some View {
        if #available(macOS 26.0, *) {
            Image(systemName: "sparkle.text.clipboard")
        } else {
            Image("sparkle.text.clipboard")
        }
    }
}

// MARK: - History Helpers

enum HistoryHelpers {
    static func searchKeyword(from pd: PasteDataStore) -> String {
        pd.lastDataChangeType == .searchFilter ? pd.currentSearchKeyword : ""
    }

    static func quickPasteIndex(for index: Int, isPressed: Bool) -> Int? {
        guard isPressed, index < 9 else { return nil }
        return index + 1
    }

    static func updateSelectionAfterDeletion(
        at index: Int,
        dataList: [PasteboardModel],
        historyVM: HistoryViewModel
    ) {
        if dataList.isEmpty {
            historyVM.setSelection(id: nil, index: 0)
        } else {
            let newIndex = min(index, dataList.count - 1)
            historyVM.setSelection(
                id: dataList[newIndex].id,
                index: newIndex
            )
        }
    }

    static func deleteItem(
        at index: Int,
        historyVM: HistoryViewModel,
        env: AppEnvironment
    ) {
        let pd = PasteDataStore.main
        guard index < pd.dataList.count else { return }
        let item = pd.dataList[index]

        historyVM.isDel = true

        _ = withAnimation(.easeInOut(duration: 0.2)) {
            pd.dataList.remove(at: index)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            updateSelectionAfterDeletion(
                at: index,
                dataList: pd.dataList,
                historyVM: historyVM
            )
            historyVM.isDel = false
        }

        env.actions.delete(item)

        if pd.dataList.count < 50,
           pd.hasMoreData,
           !pd.isLoadingPage
        {
            pd.loadNextPage()
        }
    }

    static func showDeleteConfirmAlert(
        for index: Int,
        historyVM: HistoryViewModel,
        env: AppEnvironment,
        onConfirm: @escaping () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = "确认删除吗？"
        alert.informativeText = "删除后无法恢复"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            defer {
                env.isShowDel = false
            }

            guard response == .alertFirstButtonReturn,
                  historyVM.selectedIndex == index
            else {
                return
            }

            onConfirm()
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

// MARK: - Tap Handler

struct HistoryTapHandler {
    let env: AppEnvironment
    let historyVM: HistoryViewModel

    func handleTap(
        on item: PasteboardModel,
        index: Int,
        doubleTapAction: () -> Void
    ) {
        if env.focusView != .history {
            env.focusView = .history
        }

        let now = ProcessInfo.processInfo.systemUptime
        let isSameItem = historyVM.selectedId == item.id

        if isSameItem,
           historyVM.shouldHandleDoubleTap(
               for: item.id,
               currentTime: now,
               interval: 0.3
           )
        {
            doubleTapAction()
            historyVM.resetTapState()
            return
        }

        if !isSameItem {
            historyVM.setSelection(id: item.id, index: index)
        }
        historyVM.updateTapState(id: item.id, time: now)
    }
}

// MARK: - Enumerated ForEach

struct EnumeratedForEach<Data: RandomAccessCollection, Content: View>: View
    where Data.Element: Identifiable

{
    let data: Data
    let content: (Int, Data.Element) -> Content

    init(
        _ data: Data,
        @ViewBuilder content: @escaping (Int, Data.Element) -> Content
    ) {
        self.data = data
        self.content = content
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            ForEach(data.enumerated(), id: \.element.id) { index, item in
                content(index, item)
            }
        } else {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                content(index, item)
            }
        }
    }
}
