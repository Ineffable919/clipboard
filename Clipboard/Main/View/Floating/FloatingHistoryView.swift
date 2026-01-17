//
//  FloatingHistoryView.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import AppKit
import SwiftUI

struct FloatingHistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var historyVM = HistoryViewModel()
    @FocusState private var isFocused: Bool

    private let pd = PasteDataStore.main

    var body: some View {
        ScrollViewReader { proxy in
            if pd.dataList.isEmpty {
                emptyStateView
            } else {
                ScrollView(showsIndicators: false) {
                    contentView()
                }
                .contentMargins(.top, FloatConst.headerHeight, for: .scrollContent)
                .contentMargins(.top, FloatConst.headerHeight, for: .scrollIndicators)
                .contentMargins(.bottom, FloatConst.footerHeight, for: .scrollContent)
                .contentMargins(.bottom, FloatConst.footerHeight, for: .scrollIndicators)
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
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear {
            if historyVM.selectedId == nil {
                historyVM.setSelection(id: pd.dataList.first?.id, index: 0)
            }
        }
    }

    private var emptyStateView: some View {
        ClipboardEmptyStateView(style: .floating)
    }

    private func contentView() -> some View {
        LazyVStack(spacing: FloatConst.cardSpacing) {
            EnumeratedForEach(pd.dataList) { index, item in
                cardItem(item: item, index: index)
            }
        }
        .padding(.horizontal, FloatConst.horizontalPadding)
        .padding(.vertical, FloatConst.cardSpacing)
    }

    private func cardItem(item: PasteboardModel, index: Int) -> some View {
        FloatingCardView(
            model: item,
            isSelected: historyVM.selectedId == item.id,
            showPreviewId: $historyVM.showPreviewId,
            quickPasteIndex: quickPasteIndex(for: index),
            searchKeyword: searchKeyword,
            onTap: { handleTap(on: item, index: index) },
            onRequestDelete: { requestDelete(id: item.id) }
        )
        .task(id: item.id) {
            guard historyVM.shouldLoadNextPage(at: index) else { return }
            historyVM.loadNextPageIfNeeded(at: index)
        }
    }

    private var searchKeyword: String {
        HistoryHelpers.searchKeyword(from: pd)
    }

    private func quickPasteIndex(for index: Int) -> Int? {
        HistoryHelpers.quickPasteIndex(
            for: index,
            isPressed: historyVM.isQuickPastePressed
        )
    }

    private func handleTap(on item: PasteboardModel, index: Int) {
        let handler = HistoryTapHandler(env: env, historyVM: historyVM)
        handler.handleTap(on: item, index: index) {
            env.actions.paste(item, isAttribute: true)
        }
    }

    private func requestDelete(id: PasteboardModel.ID) {
        guard let index = pd.dataList.firstIndex(where: { $0.id == id }) else {
            return
        }

        let item = pd.dataList[index]
        env.actions.delete(item)

        withAnimation(.easeInOut(duration: 0.2)) {
            pd.dataList.remove(at: index)
            updateSelectionAfterDeletion(at: index)
        }
    }

    private func updateSelectionAfterDeletion(at index: Int) {
        HistoryHelpers.updateSelectionAfterDeletion(
            at: index,
            dataList: pd.dataList,
            historyVM: historyVM
        )
    }
}

// MARK: - Bottom Margins Modifier

private struct BottomMarginsModifier: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .contentMargins(.bottom, height, for: .scrollContent)
                .contentMargins(.bottom, height, for: .scrollIndicators)
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview {
    let env = AppEnvironment()
    FloatingHistoryView()
        .environment(env)
        .frame(width: 350, height: 670)
}
