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
    @AppStorage(PrefKey.enableLinkPreview.rawValue)
    private var enableLinkPreview: Bool = PasteUserDefaults.enableLinkPreview

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
                .onChange(of: env.focusView) { _, newValue in
                    isFocused = (newValue == .history)
                }
                .onChange(of: historyVM.activeId) { _, newId in
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
            isSelected: historyVM.isItemSelected(item.id),
            showPreviewId: $historyVM.showPreviewId,
            quickPasteIndex: historyVM.quickPasteIndex(for: index),
            enableLinkPreview: enableLinkPreview,
            searchKeyword: historyVM.searchKeyword,
            onRequestDelete: { requestDelete(index: index) },
            onPaste: { historyVM.pasteSelectedItems(checkPermissions: true) },
            onPastePlainText: {
                historyVM.pasteSelectedItems(
                    isAttribute: false,
                    checkPermissions: PasteUserDefaults.pasteDirect
                )
            },
            onCopy: { historyVM.copySelectedItems() }
        )
        .id(item.id)
        .contentShape(.rect)
        .onTapGesture {
            handleTap(on: item, index: index)
        }
        .onDrag {
            env.draggingItemId = item.id
            if env.focusView != .history {
                env.focusView = .history
            }
            historyVM.selectSingle(id: item.id)
            return item.itemProvider()
        }
        .task(id: item.id) {
            guard historyVM.shouldLoadNextPage(at: index) else { return }
            historyVM.loadNextPageIfNeeded(at: index)
        }
    }

    private func handleTap(on item: PasteboardModel, index: Int) {
        let isCommandHeld = NSEvent.modifierFlags.contains(.command)
        historyVM.handleTap(
            on: item,
            index: index,
            isCommandHeld: isCommandHeld
        ) {
            historyVM.pasteSelectedItems(
                checkPermissions: PasteUserDefaults.pasteDirect
            )
        }
    }

    private func requestDelete(index: Int? = nil) {
        let targetIndex = index ?? historyVM.activeIndex
        guard let targetIndex else { return }

        guard PasteUserDefaults.delConfirm else {
            historyVM.deleteItem(at: targetIndex)
            return
        }
        env.isShowDel = true
        historyVM.showDeleteConfirmAlert { [self] in
            historyVM.deleteItem(at: targetIndex)
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

        if historyVM.activeId == nil {
            historyVM.selectSingle(id: pd.dataList.first?.id)
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
            historyVM.selectSingle(id: nil)
            NSSound.beep()
            return nil
        }

        let currentIndex = historyVM.activeIndex ?? 0
        let newIndex = max(0, min(currentIndex + offset, pd.dataList.count - 1))

        guard newIndex != currentIndex else {
            NSSound.beep()
            return nil
        }

        historyVM.selectSingle(id: pd.dataList[newIndex].id)
        if historyVM.showPreviewId != nil {
            historyVM.showPreviewId = nil
        }

        if offset > 0, historyVM.shouldLoadNextPage(at: newIndex) {
            Task(priority: .userInitiated) { [weak historyVM] in
                historyVM?.loadNextPageIfNeeded(at: newIndex)
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
        historyVM.selectSingle(id: item.id)
        ClipActionService.shared.paste(item, isAttribute: true)
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
            historyVM.copySelectedItems()
            return nil

        case UInt16(kVK_ANSI_E):
            return handleEdit()

        case UInt16(kVK_ANSI_A):
            historyVM.selectFirstNine()
            return nil

        default:
            return event
        }
    }

    private func handleEdit() -> NSEvent? {
        guard let index = historyVM.activeIndex else {
            NSSound.beep()
            return nil
        }
        EditWindowController.shared.openWindow(with: pd.dataList[index])
        return nil
    }

    private func handleSpace(_: NSEvent) -> NSEvent? {
        if let id = historyVM.activeId {
            if historyVM.showPreviewId == id {
                historyVM.showPreviewId = nil
            } else {
                historyVM.showPreviewId = id
            }
        }
        return nil
    }

    private func handleReturnKey(_ event: NSEvent) -> NSEvent? {
        guard !historyVM.selectedIds.isEmpty else { return event }
        historyVM.pasteSelectedItems(
            isAttribute: !hasPlainTextModifier(event),
            checkPermissions: true
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
        guard historyVM.activeIndex != nil else {
            NSSound.beep()
            return nil
        }
        requestDelete()
        return nil
    }
}

// MARK: - Drag Preview View

private struct DragPreviewView: View {
    let model: PasteboardModel

    var body: some View {
        Image(systemName: iconName)
            .imageScale(.large)
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
