//
//  HistoryView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import SwiftUI

struct HistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var historyVM = HistoryViewModel()
    @FocusState private var isFocused: Bool
    @AppStorage(PrefKey.enableLinkPreview.rawValue)
    private var enableLinkPreview: Bool = PasteUserDefaults.enableLinkPreview
    @AppStorage(PrefKey.displayMode.rawValue) private var displayModeRaw: Int = 0
    private let pd = PasteDataStore.main

    var body: some View {
        VStack {
            if pd.dataList.isEmpty {
                ClipboardEmptyStateView(style: .main)
            } else {
                scrollContent
            }
        }
        .onChange(of: displayModeRaw) {
            historyVM.handleModeSwitch()
        }
        .onChange(of: pd.dataList) {
            historyVM.reset()
        }
        .onChange(of: env.quickPasteResetTrigger) {
            historyVM.isQuickPastePressed = false
        }
        .onAppear {
            historyVM.onAppear(env: env)
        }
        .onDisappear {
            historyVM.onDisappear()
        }
    }

    private var scrollContent: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: Const.cardSpace) {
                EnumeratedForEach(pd.dataList) { index, item in
                    HistoryCardItemView(
                        item: item,
                        index: index,
                        historyVM: historyVM,
                        enableLinkPreview: enableLinkPreview
                    )
                }
            }
            .padding(.vertical, Const.space4)
        }
        .horizontalMouseWheelScroll()
        .scrollIndicators(.never)
        .scrollPosition($historyVM.scrollPosition)
        .contentMargins(
            .leading,
            Const.cardLeadingSpace,
            for: .scrollContent
        )
        .contentMargins(
            .trailing,
            Const.cardSpace,
            for: .scrollContent
        )
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onChange(of: env.focusView) {
            isFocused = (env.focusView == .history)
        }
        .onChange(of: historyVM.activeId) { _, newId in
            if let id = newId {
                historyVM.scrollPosition.scrollTo(
                    id: id,
                    anchor: historyVM.scrollAnchor()
                )
            }
        }
    }
}

// MARK: - Card Item View

private struct HistoryCardItemView: View {
    let item: PasteboardModel
    let index: Int
    let historyVM: HistoryViewModel
    let enableLinkPreview: Bool

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ClipCardView(
            model: item,
            isSelected: historyVM.isItemSelected(item.id),
            showPreviewId: Bindable(historyVM).showPreviewId,
            quickPasteIndex: historyVM.quickPasteIndex(for: index),
            enableLinkPreview: enableLinkPreview,
            searchKeyword: historyVM.searchKeyword,
            onRequestDelete: { historyVM.requestDelete(at: index) },
            onPaste: {
                historyVM.pasteSelectedItems(checkPermissions: true)
            },
            onPastePlainText: {
                historyVM.pasteSelectedItems(
                    isAttribute: false,
                    checkPermissions: PasteUserDefaults.pasteDirect
                )
            },
            onCopy: { historyVM.copySelectedItems() }
        )
        .contentShape(.rect)
        .transition(
            .asymmetric(
                insertion: .identity,
                removal: .opacity.combined(with: .scale(scale: 0.92))
            )
        )
        .onTapGesture {
            historyVM.handleOptimisticTap(on: item, index: index)
        }
        .onDrag {
            env.draggingItemId = item.id
            env.focusView = .history
            historyVM.selectSingle(id: item.id)
            return item.itemProvider()
        }
        .task(id: item.id) {
            guard historyVM.shouldLoadNextPage(at: index) else { return }
            historyVM.loadNextPageIfNeeded(at: index)
        }
    }
}
