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
        static let deleteAnimationDelay: TimeInterval = 0.3
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
    let pd = PasteDataStore.main
    @State private var selectionState = SelectionState()
    @State private var showPreviewId: PasteboardModel.ID?
    @State private var monitor: Any?
    @State private var flagsMonitor: Any?
    @State private var isDel: Bool = false
    @State private var isQuickPasteModifierPressed: Bool = false
    @State private var lastLoadTriggerIndex: Int = -1

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                if pd.dataList.isEmpty {
                    emptyStateView
                } else {
                    contentView(proxy: proxy)
                }
            }
            .onChange(of: selectionState.selectedId, initial: false) {
                scrollToSelectedId(proxy: proxy)
            }
            .onChange(of: pd.dataList) { _, _ in
                guard !isDel else { return }
                lastLoadTriggerIndex = -1
                let changeType = pd.lastDataChangeType
                if changeType == .searchFilter || changeType == .reset {
                    reset()
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

    private var emptyStateView: some View {
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
        .padding(.vertical, 4)
        .frame(width: Const.cardSize, height: Const.emptySize)
    }

    private func contentView(proxy _: ScrollViewProxy) -> some View {
        LazyHStack(alignment: .top, spacing: Const.cardSpace) {
            ForEach(Array(pd.dataList.enumerated()), id: \.element.id) { index, item in
                ClipCardView(
                    model: item,
                    isSelected: selectionState.selectedId == item.id,
                    showPreview: makePreviewBinding(for: item.id),
                    isHistoryFocused: vm.focusView == .history,
                    quickPasteIndex: isQuickPasteModifierPressed && index < 9
                        ? index + 1 : nil,
                    onRequestDelete: { requestDel(id: item.id) },
                )
                .id(item.id)
                .onTapGesture { handleOptimisticTap(on: item) }
                .onDrag { itemProvider(for: item) }
                .onAppear {
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

    /// 判断是否应该在当前索引触发加载
    private func shouldLoadNextPage(at index: Int) -> Bool {
        guard pd.dataList.count >= 50 else { return false }
        let triggerIndex = pd.dataList.count - 5
        return index >= max(0, triggerIndex)
    }

    /// 加载下一页（如果需要）
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

        defer {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Constants.deleteAnimationDelay,
            ) {
                self.isDel = false
            }
        }
        let item = pd.dataList[index]
        vm.deleteAction(item: item)

        withAnimation(.easeOut(duration: 0.2)) {
            pd.dataList.remove(at: index)
            updateSelectionAfterDeletion(at: index)
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

        if id == first {
            proxy.scrollTo(id, anchor: .trailing)
        } else if id == last {
            proxy.scrollTo(id, anchor: .leading)
        } else {
            proxy.scrollTo(id)
        }
    }

    private func moveSelection(offset: Int) {
        guard vm.focusView == .history else { return }
        let count = pd.dataList.count
        guard count > 0 else {
            selectionState.selectedId = nil
            showPreviewId = nil
            NSSound.beep()
            return
        }

        let currentIndex =
            selectionState.selectedId.flatMap { id in
                pd.dataList.firstIndex { $0.id == id }
            } ?? 0

        let newIndex = max(0, min(currentIndex + offset, count - 1))

        guard newIndex != currentIndex else {
            NSSound.beep()
            return
        }
        let newId = pd.dataList[newIndex].id
        selectionState.selectedId = newId

        if offset > 0, shouldLoadNextPage(at: newIndex) {
            loadNextPageIfNeeded(at: newIndex)
        }
    }

    private func appear() {
        monitor = EventMonitorManager.shared.addLocalMonitor(
            type: .historyArea,
            matching: .keyDown,
            handler: keyDownEvent(_:),
        )

        flagsMonitor = EventMonitorManager.shared.addLocalMonitor(
            type: .historyFlags,
            matching: .flagsChanged,
            handler: flagsChangedEvent(_:),
        )

        if selectionState.selectedId == nil {
            selectionState.selectedId = pd.dataList.first?.id
        }
    }

    private func cleanup() {
        EventMonitorManager.shared.removeMonitor(type: .historyArea)
        EventMonitorManager.shared.removeMonitor(type: .historyFlags)

        monitor = nil
        flagsMonitor = nil
        isDel = false
        isQuickPasteModifierPressed = false
    }

    private func flagsChangedEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window === ClipMainWindowController.shared.window else {
            return event
        }

        let newState = KeyCode.isQuickPasteModifierPressed()
        if newState != isQuickPasteModifierPressed {
            isQuickPasteModifierPressed = newState
        }
        return event
    }

    private func keyDownEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window === ClipMainWindowController.shared.window else {
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
            moveSelection(offset: -1)
            return nil

        case UInt16(kVK_RightArrow):
            moveSelection(offset: 1)
            return nil

        case UInt16(kVK_Space):
            return handleSpace(event)

        case UInt16(kVK_Return):
            return handleReturnKey(event)

        case UInt16(kVK_Delete), UInt16(kVK_ForwardDelete):
            deleteKeyDown()
            return nil

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

        // 检查是否同时按下了其他修饰键（除了快速粘贴修饰键之外）
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

    /// - Parameter index: 剪贴板项索引（0-8）
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

    private func deleteKeyDown() {
        guard vm.focusView == .history else { return }
        guard let id = selectionState.selectedId else {
            NSSound.beep()
            return
        }
        requestDel(id: id)
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

    private func reset() {
        if pd.dataList.isEmpty {
            selectionState.selectedId = nil
            showPreviewId = nil
            return
        }
        selectionState.selectedId = pd.dataList.first?.id
    }

    private func itemProvider(for model: PasteboardModel) -> NSItemProvider {
        let provider = NSItemProvider()
        let modeId = model.id
        // 1️⃣ 内部拖拽
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.clipType.identifier,
            visibility: .all,
        ) { completion in
            let idData = withUnsafeBytes(of: modeId) { Data($0) }
            completion(idData, nil)
            return nil
        }

        // 2️⃣ 处理文本
        if model.pasteboardType.isText() {
            provider.registerDataRepresentation(
                forTypeIdentifier: model.pasteboardType.rawValue,
                visibility: .all,
            ) { completion in
                completion(model.data, nil)
                return nil
            }
            provider.suggestedName = "文本"
        }

        // 3️⃣ 处理图片
        if model.type == .image {
            provider.registerDataRepresentation(
                forTypeIdentifier: model.pasteboardType.rawValue,
                visibility: .all,
            ) { completion in
                completion(model.data, nil)
                return nil
            }
            provider.suggestedName = "图片"
        }

        // 4️⃣ 处理文件
        if model.type == .file {
            if let filePaths = String(data: model.data, encoding: .utf8) {
                let paths =
                    filePaths
                        .split(separator: "\n")
                        .map {
                            String($0).trimmingCharacters(
                                in: .whitespacesAndNewlines,
                            )
                        }
                        .filter { !$0.isEmpty }

                for path in paths {
                    let fileURL = URL(fileURLWithPath: path)
                    if FileManager.default.fileExists(atPath: path) {
                        let promisedType: String = promisedTypeIdentifier(
                            for: fileURL,
                        )
                        provider.registerFileRepresentation(
                            forTypeIdentifier: promisedType,
                            fileOptions: [],
                            visibility: .all,
                        ) { completion in
                            DispatchQueue.global(qos: .userInitiated).async {
                                do {
                                    // Copy to a temp location we can read, so Finder can pull without sandbox extensions.
                                    let tmpDir = URL(
                                        fileURLWithPath: NSTemporaryDirectory(),
                                        isDirectory: true,
                                    )
                                    let dst = tmpDir.appendingPathComponent(
                                        fileURL.lastPathComponent,
                                        isDirectory: false,
                                    )
                                    if FileManager.default.fileExists(
                                        atPath: dst.path,
                                    ) {
                                        try? FileManager.default.removeItem(
                                            at: dst,
                                        )
                                    }
                                    try FileManager.default.copyItem(
                                        at: fileURL,
                                        to: dst,
                                    )
                                    completion(
                                        dst, /* isInPlace: */
                                        false,
                                        nil,
                                    )
                                } catch {
                                    completion(nil, false, error)
                                }
                            }
                            return nil
                        }
                    }
                }

                if paths.count == 1 {
                    provider.suggestedName =
                        URL(fileURLWithPath: paths[0]).lastPathComponent
                } else {
                    provider.suggestedName = "\(paths.count)个文件"
                }
            }
        }

        return provider
    }

    private func promisedTypeIdentifier(for fileURL: URL) -> String {
        do {
            let values = try fileURL.resourceValues(forKeys: [
                .contentTypeKey,
            ])
            if let type = values.contentType {
                return type.identifier
            }
        } catch {
            // ignore and fall through to fallback
        }
        return UTType.data.identifier
    }

    private func showDeleteAlert() {
        let alert = NSAlert()
        alert.messageText = "确认删除吗？"
        alert.informativeText = "删除后无法恢复"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        let handleResponse: (NSApplication.ModalResponse) -> Void = { [self] response in
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
                alert.beginSheetModal(for: window, completionHandler: handleResponse)
            }
        } else {
            let response = alert.runModal()
            handleResponse(response)
        }
    }
}
