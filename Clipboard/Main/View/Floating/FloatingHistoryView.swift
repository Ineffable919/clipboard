//
//  FloatingHistoryView.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import AppKit
import Carbon
import SwiftUI

struct FloatingHistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var historyVM = HistoryViewModel()
    @FocusState private var isFocused: Bool
    @State private var flagsMonitorToken: Any?

    private let pd = PasteDataStore.main

    var body: some View {
        ScrollViewReader { proxy in
            if pd.dataList.isEmpty {
                ClipboardEmptyStateView(style: .floating)
            } else {
                ScrollView {
                    contentView()
                }
                .scrollIndicators(.automatic)
                .contentMargins(
                    .top,
                    FloatConst.headerHeight + FloatConst.cardSpacing,
                    for: .scrollContent
                )
                .contentMargins(
                    .top,
                    FloatConst.headerHeight,
                    for: .scrollIndicators
                )
                .contentMargins(
                    .bottom,
                    FloatConst.footerHeight + FloatConst.cardSpacing,
                    for: .scrollContent
                )
                .contentMargins(
                    .bottom,
                    FloatConst.footerHeight,
                    for: .scrollIndicators
                )
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
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear {
            appear()
        }
        .onDisappear {
            disappear()
        }
    }

    private func contentView() -> some View {
        LazyVStack(spacing: FloatConst.cardSpacing) {
            EnumeratedForEach(pd.dataList) { index, item in
                cardItem(item: item, index: index)
            }
        }
        .padding(.horizontal, Const.space16)
    }

    private func cardItem(item: PasteboardModel, index: Int) -> some View {
        FloatingCardView(
            model: item,
            isSelected: historyVM.selectedId == item.id,
            showPreviewId: $historyVM.showPreviewId,
            quickPasteIndex: historyVM.quickPasteIndex(for: index),
            searchKeyword: historyVM.searchKeyword,
            onRequestDelete: { requestDelete(index: index) }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap(on: item, index: index)
        }
        .onDrag {
            env.draggingItemId = item.id
            if env.focusView != .history {
                env.focusView = .history
            }
            historyVM.setSelection(id: item.id, index: index)
            return item.itemProvider()
        }
        .task(id: item.id) {
            guard historyVM.shouldLoadNextPage(at: index) else { return }
            historyVM.loadNextPageIfNeeded(at: index)
        }
    }

    private func handleTap(on item: PasteboardModel, index: Int) {
        historyVM.handleTap(on: item, index: index) {
            env.actions.paste(item, isAttribute: true)
        }
    }

    private func requestDelete(index: Int) {
        guard PasteUserDefaults.delConfirm else {
            historyVM.deleteItem(at: index)
            return
        }
        env.isShowDel = true
        historyVM.showDeleteConfirmAlert(for: index) { [self] in
            historyVM.deleteItem(at: index)
        }
    }

    // MARK: - Event Handlers

    private func appear() {
        historyVM.configure(env: env)
        EventDispatcher.shared.registerHandler(
            matching: .keyDown,
            key: "floating",
            handler: keyDownEvent(_:)
        )

        flagsMonitorToken = NSEvent.addLocalMonitorForEvents(
            matching: .flagsChanged
        ) { event in
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
        guard event.window == ClipFloatingWindowController.shared.window,
              ClipFloatingWindowController.shared.isVisible
        else {
            return event
        }

        historyVM.isQuickPastePressed = KeyCode.isQuickPasteModifierPressed()
        return event
    }

    private func keyDownEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window == ClipFloatingWindowController.shared.window
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
            if ClipFloatingWindowController.shared.isVisible {
                ClipFloatingWindowController.shared.toggleWindow()
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

        let hasModifiers = !event.modifierFlags
            .intersection([.command, .option, .control, .shift])
            .isEmpty

        switch event.keyCode {
        case UInt16(kVK_UpArrow):
            if hasModifiers {
                return event
            }
            return moveSelection(offset: -1, event: event)

        case UInt16(kVK_DownArrow):
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

    private func performQuickPaste(at index: Int) {
        guard index >= 0, index < pd.dataList.count else {
            NSSound.beep()
            return
        }

        let item = pd.dataList[index]
        historyVM.setSelection(id: item.id, index: index)
        env.actions.paste(
            item,
            isAttribute: true
        )
    }

    private func handleCommandKeyEvent(_ event: NSEvent) -> NSEvent? {
        let hasModifiers = !event.modifierFlags.intersection([
            .option, .control, .shift,
        ]).isEmpty
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
            isAttribute: !hasPlainTextModifier(event)
        )
        return nil
    }

    private func hasPlainTextModifier(_ event: NSEvent) -> Bool {
        KeyCode.hasModifier(
            event,
            modifierIndex: PasteUserDefaults.plainTextModifier
        )
    }

    private func deleteKeyDown(_: NSEvent) -> NSEvent? {
        guard let index = historyVM.selectedIndex else {
            NSSound.beep()
            return nil
        }
        requestDelete(index: index)
        return nil
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

// MARK: - Drag Preview View

private struct DragPreviewView: View {
    let model: PasteboardModel

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 32, weight: .regular))
            .frame(width: 48, height: 48)
    }

    private var iconName: String {
        switch model.type {
        case .image:
            "photo"
        case .string, .rich:
            "doc.text"
        case .file:
            "folder"
        case .link:
            "link"
        case .color:
            "paintpalette"
        case .none:
            "doc"
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
