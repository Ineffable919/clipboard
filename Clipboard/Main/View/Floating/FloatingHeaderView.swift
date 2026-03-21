//
//  FloatingHeaderView.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import SwiftUI
import UniformTypeIdentifiers

struct FloatingHeaderView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(TopBarViewModel.self) private var topBarVM
    @AppStorage(PrefKey.backgroundType.rawValue) private var backgroundTypeRaw:
        Int = 0
    @FocusState private var focus: FocusField?

    var body: some View {
        VStack(spacing: 0) {
            TopDragArea()

            HStack(spacing: Const.space12) {
                PinButton()
                SearchFieldView(topBarVM: topBarVM, focus: $focus)
                SettingsMenuView(topBarVM: topBarVM)
            }
            .padding(.horizontal, Const.space16)
            .padding(.vertical, Const.space4)

            ChipScrollView(topBarVM: topBarVM, focus: $focus)
                .frame(height: 42)
        }
        .frame(maxWidth: .infinity)
        .frame(height: FloatConst.headerHeight)
        .onAppear {
            EventDispatcher.shared.registerHandler(
                matching: .keyDown,
                key: "floatingTop",
                handler: floatingKeyDownEvent(_:)
            )
            topBarVM.startPauseDisplayTimer()
        }
    }

    // MARK: - 键盘事件处理

    private func floatingKeyDownEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window === ClipFloatingWindowController.shared.window
        else {
            return event
        }

        let isInInputMode = env.isInInputMode()

        if !isInInputMode,
           EventDispatcher.shared.handleTab(
               event,
               viewModel: topBarVM
           )
        {
            return nil
        }

        if isInInputMode {
            if EventDispatcher.shared.handleSystemEditingCommand(event) {
                return nil
            }

            if event.keyCode == KeyCode.escape {
                if topBarVM.isEditingChip {
                    topBarVM.cancelEditingChip()
                    env.focusView = .history
                    return nil
                }
                if topBarVM.editingNewChip {
                    topBarVM.commitNewChipOrCancel(commitIfNonEmpty: false)
                    env.focusView = .history
                    return nil
                }
                if topBarVM.hasInput {
                    topBarVM.clearInput()
                } else {
                    env.focusView = .history
                }
                return nil
            }

            return event
        }

        if KeyCode.shouldTriggerSearch(for: event) {
            focus = .search
            return nil
        }

        return event
    }
}

// MARK: - 顶部拖拽区域

private struct TopDragArea: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Button {
            env.focusView = .history
        } label: {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: Const.space6)

                RoundedRectangle(cornerRadius: 2.0)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36.0, height: 4.0)

                Spacer()
                    .frame(height: Const.space6)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .windowDraggable()
    }
}

struct PinButton: View {
    @State private var isPinned: Bool = false

    var body: some View {
        Button(
            String(localized: isPinned ? .unpin : .pin),
            systemImage: isPinned ? "pin.fill" : "pin"
        ) {
            isPinned.toggle()
            ClipFloatingWindowController.shared.isPinned = isPinned
        }
        .labelStyle(.iconOnly)
        .foregroundStyle(isPinned ? Color.accentColor : .secondary)
        .buttonStyle(.plain)
        .help(String(localized: isPinned ? .unpin : .pin))
    }
}

// MARK: - 分类标签区域

private struct ChipScrollView: View {
    @Bindable var topBarVM: TopBarViewModel
    @FocusState.Binding var focus: FocusField?

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        HStack(spacing: 0) {
            ChipScrollContentView(
                topBarVM: topBarVM,
                focus: $focus,
                onBackgroundTap: {
                    guard env.focusView != .history else { return }
                    focus = nil
                    env.focusView = .history
                }
            )

            if !topBarVM.editingNewChip {
                Button("", systemImage: "plus") {
                    if !topBarVM.editingNewChip {
                        topBarVM.editingNewChip = true
                    } else {
                        topBarVM.commitNewChipOrCancel(commitIfNonEmpty: true)
                    }
                    env.focusView = .newChip
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .padding(.trailing, Const.space16)
                .padding(.leading, Const.space6)
            }
        }
    }
}

// MARK: - 分类标签滚动视图

private struct ChipScrollContentView: View {
    @Bindable var topBarVM: TopBarViewModel
    @FocusState.Binding var focus: FocusField?
    let onBackgroundTap: () -> Void

    var body: some View {
        if #available(macOS 15.0, *) {
            ChipScrollListWithPosition(
                topBarVM: topBarVM,
                focus: $focus,
                onBackgroundTap: onBackgroundTap
            )
        } else {
            ScrollViewReader { proxy in
                ChipScrollList(
                    topBarVM: topBarVM,
                    focus: $focus,
                    onBackgroundTap: onBackgroundTap
                )
                .onChange(of: topBarVM.editingNewChip) { _, isEditing in
                    if isEditing {
                        withAnimation {
                            proxy.scrollTo("newChipEditor", anchor: .trailing)
                        }
                    }
                }
                .onChange(of: topBarVM.selectedChipId) { _, newId in
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
        }
    }
}

@available(macOS 15.0, *)
private struct ChipScrollListWithPosition: View {
    @Bindable var topBarVM: TopBarViewModel
    @FocusState.Binding var focus: FocusField?
    let onBackgroundTap: () -> Void

    @State private var scrollPosition = ScrollPosition()

    var body: some View {
        ChipScrollList(
            topBarVM: topBarVM,
            focus: $focus,
            onBackgroundTap: onBackgroundTap
        )
        .scrollPosition($scrollPosition)
        .onChange(of: topBarVM.editingNewChip) { _, isEditing in
            if isEditing {
                withAnimation {
                    scrollPosition.scrollTo(
                        id: "newChipEditor",
                        anchor: .trailing
                    )
                }
            }
        }
        .onChange(of: topBarVM.selectedChipId) { _, newId in
            scrollPosition.scrollTo(id: newId, anchor: .center)
        }
    }
}

private struct ChipScrollList: View {
    @Bindable var topBarVM: TopBarViewModel
    @FocusState.Binding var focus: FocusField?
    let onBackgroundTap: () -> Void

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Const.space6) {
                ForEach(topBarVM.chips) { chip in
                    FloatingChipView(
                        chip: chip,
                        isSelected: topBarVM.selectedChipId == chip.id,
                        topBarVM: topBarVM,
                        focus: $focus,
                        onTap: {
                            topBarVM.toggleChip(chip)
                            onBackgroundTap()
                        }
                    )
                    .id(chip.id)
                }

                if topBarVM.editingNewChip {
                    ChipEditorView(
                        name: $topBarVM.newChipName,
                        color: $topBarVM.newChipColor,
                        focus: $focus,
                        focusValue: .newChip,
                        onSubmit: {
                            topBarVM.commitNewChipOrCancel(
                                commitIfNonEmpty: true
                            )
                            env.focusView = .history
                        },
                        onCycleColor: {
                            let nextIndex =
                                (topBarVM.newChipColorIndex + 1)
                                    % CategoryChip.palette.count
                            topBarVM.newChipColorIndex = nextIndex
                        }
                    )
                    .onChange(of: env.focusView) { _, newValue in
                        if newValue != .newChip {
                            topBarVM.commitNewChipOrCancel(
                                commitIfNonEmpty: true
                            )
                        }
                    }
                    .id("newChipEditor")
                }
            }
            .padding(.leading, Const.space16)
            .padding(.trailing, Const.space6)
            .padding(.vertical, Const.space6)
        }
        .scrollIndicators(.hidden)
        .horizontalMouseWheelScroll()
        .contentShape(.rect)
        .onTapGesture {
            onBackgroundTap()
        }
    }
}

// MARK: - 分类标签视图

struct FloatingChipView: View {
    let chip: CategoryChip
    let isSelected: Bool
    @Bindable var topBarVM: TopBarViewModel
    @FocusState.Binding var focus: FocusField?
    let onTap: () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var isDropTargeted = false

    private var pd: PasteDataStore {
        PasteDataStore.main
    }

    private var isEditing: Bool {
        topBarVM.editingChipId == chip.id
    }

    var body: some View {
        Group {
            if isEditing {
                ChipEditingView(topBarVM: topBarVM, focus: $focus)
            } else {
                ChipNormalView(chip: chip, isSelected: isSelected, onTap: onTap)
            }
        }
        .overlay {
            if !chip.isSystem {
                ChipContextMenuHelper(
                    chip: chip,
                    onEdit: {
                        topBarVM.startEditingChip(chip)
                        env.focusView = .editChip
                    },
                    onDelete: {
                        env.isShowDel = true
                        showDelAlert(chip)
                    },
                    onColorChange: { colorIndex in
                        updateChipColor(colorIndex: colorIndex)
                    },
                    onHoverChanged: { _ in }
                )
            }
        }
        .onDrop(
            of: ChipDropTypes.types,
            isTargeted: $isDropTargeted
        ) { _ in
            handleDrop()
        }
    }

    private func handleDrop() -> Bool {
        guard let draggingId = env.draggingItemId else {
            return false
        }

        guard let item = pd.dataList.first(where: { $0.id == draggingId })
        else {
            return false
        }

        if item.group == chip.id {
            return true
        }

        if let selectedChip = topBarVM.chips.first(where: {
            $0.id == topBarVM.selectedChipId
        }),
            !selectedChip.isSystem
        {
            var list = pd.dataList
            list.removeAll(where: { $0.id == item.id })
            pd.dataList = list
        }

        do {
            try PasteDataStore.main.updateItemGroup(
                itemId: draggingId,
                groupId: chip.id
            )
        } catch {
            log.error("更新卡片 group 失败: \(error)")
            return false
        }
        return true
    }

    private func updateChipColor(colorIndex: Int) {
        let newColor = CategoryChip.palette[colorIndex]
        topBarVM.updateChip(chip, color: newColor)
    }

    private func showDelAlert(_ chip: CategoryChip) {
        let alert = NSAlert()
        alert.messageText = String(localized: .deleteChipTitle(chip.name))
        alert.informativeText = String(localized: .deleteChipMessage(chip.name))
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: .commonConfirm))
        alert.addButton(withTitle: String(localized: .commonCancel))

        let handleResponse: (NSApplication.ModalResponse) -> Void = {
            [self] response in
            defer {
                self.env.isShowDel = false
            }

            guard response == .alertFirstButtonReturn
            else {
                return
            }

            topBarVM.removeChip(chip)
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

// MARK: - チップ通常表示 / チップ編集表示

private struct ChipNormalView: View {
    let chip: CategoryChip
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(chip.name)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : .primary.opacity(0.8))
                .padding(.horizontal, Const.space10)
                .padding(.vertical, Const.space4)
                .background {
                    RoundedRectangle(cornerRadius: Const.radius)
                        .fill(
                            isSelected
                                ? chip.isSystem ? Color.accentColor : chip.color
                                : .clear
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

private struct ChipEditingView: View {
    @Bindable var topBarVM: TopBarViewModel
    @FocusState.Binding var focus: FocusField?

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ChipEditorView(
            name: $topBarVM.editingChipName,
            color: $topBarVM.editingChipColor,
            focus: $focus,
            focusValue: .editChip,
            onSubmit: {
                topBarVM.commitEditingChip()
                env.focusView = .history
            },
            onCycleColor: {
                topBarVM.cycleEditingChipColor()
            }
        )
        .onChange(of: env.focusView) { _, newValue in
            if newValue != .editChip {
                topBarVM.commitEditingChip()
            }
        }
    }
}

// MARK: - 搜索框视图

private struct SearchFieldView: View {
    @Bindable var topBarVM: TopBarViewModel
    @FocusState.Binding var focus: FocusField?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        HStack(spacing: Const.space4) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .imageScale(.small)

            TextField(text: $topBarVM.query) {
                Text(.search)
            }
            .textFieldStyle(.plain)
            .focused($focus, equals: .search)
            .onChange(of: focus) { _, newValue in
                if newValue == .search, env.focusView != .search {
                    env.focusView = .search
                }
            }

            if !topBarVM.query.isEmpty {
                Button("", systemImage: "xmark.circle.fill") {
                    topBarVM.query = ""
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
                .imageScale(.small)
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Const.space10)
        .padding(.vertical, Const.space6)
        .background {
            RoundedRectangle(cornerRadius: Const.radius)
                .fill(
                    colorScheme == .dark
                        ? Color(NSColor.controlBackgroundColor)
                        : .black.opacity(0.08)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: Const.radius)
                .strokeBorder(
                    focus == .search
                        ? Color.accentColor.opacity(0.45)
                        : Color.clear,
                    lineWidth: 3.0
                )
        }
    }
}

#Preview {
    let env = AppEnvironment()
    let topBarVM = TopBarViewModel()
    FloatingHeaderView()
        .environment(env)
        .environment(topBarVM)
        .frame(width: 370, height: FloatConst.headerHeight)
        .padding()
}
