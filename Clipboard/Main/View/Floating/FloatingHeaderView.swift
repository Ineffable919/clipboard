//
//  FloatingHeaderView.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import SwiftUI
import UniformTypeIdentifiers

struct FloatingHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppEnvironment.self) private var env
    @AppStorage(PrefKey.backgroundType.rawValue) private var backgroundTypeRaw:
        Int = 0
    @FocusState private var focus: FocusField?
    @State private var topBarVM = TopBarViewModel()
    @State private var showFilter = false

    var body: some View {
        VStack(spacing: 0) {
            topDragArea

            HStack(spacing: Const.space12) {
                searchField
                settingsButton
            }
            .padding(.top, Const.space6)
            .padding(.horizontal, FloatConst.horizontalPadding)

            Spacer()
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .windowDraggable()

            chipScrollView
                .frame(height: 42)

            Spacer()
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .windowDraggable()
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

    // MARK: - 顶部拖拽区域

    private var topDragArea: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: Const.space6)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36.0, height: 4.0)

            Spacer()
                .frame(height: Const.space4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .windowDraggable()
    }

    // MARK: - 搜索框

    private var searchField: some View {
        HStack(spacing: Const.space6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14.0, weight: .regular))
                .foregroundStyle(.secondary)

            TextField("搜索...", text: $topBarVM.query)
                .textFieldStyle(.plain)
                .focused($focus, equals: .search)
                .onChange(of: focus) {
                    if focus == .search, env.focusView != .search {
                        env.focusView = .search
                    }
                }
        }
        .padding(.horizontal, Const.space10)
        .padding(.vertical, Const.space6)
        .background {
            RoundedRectangle(cornerRadius: Const.radius)
                .fill(searchFieldBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Const.radius + 3)
                .strokeBorder(
                    focus == .search
                        ? Color.accentColor.opacity(0.45)
                        : Color.clear,
                    lineWidth: 3
                )
                .padding(-3)
        }
    }

    private var searchFieldBackground: some ShapeStyle {
        if colorScheme == .dark {
            AnyShapeStyle(Color.white.opacity(0.1))
        } else {
            AnyShapeStyle(Color.black.opacity(0.05))
        }
    }

    // MARK: - 设置按钮

    private var settingsButton: some View {
        SettingsMenuView(topBarVM: topBarVM)
    }

    // MARK: - 分类标签

    private var chipScrollView: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Const.space8) {
                ForEach(topBarVM.chips) { chip in
                    FloatingChipView(
                        chip: chip,
                        isSelected: topBarVM.selectedChipId == chip.id,
                        topBarVM: topBarVM,
                        focus: $focus,
                        onTap: {
                            topBarVM.toggleChip(chip)
                            guard env.focusView != .history else { return }
                            focus = nil
                            env.focusView = .history
                        }
                    )
                }

                if topBarVM.editingNewChip {
                    addChipEditorView
                }

                if !topBarVM.editingNewChip {
                    addChipButton
                }
            }
            .padding(.horizontal, FloatConst.horizontalPadding)
            .padding(.vertical, Const.space6)
        }
        .scrollIndicators(.hidden)
        .onTapGesture {
            guard env.focusView != .history else { return }
            focus = nil
            env.focusView = .history
        }
    }

    private var addChipEditorView: some View {
        ChipEditorView(
            name: $topBarVM.newChipName,
            color: $topBarVM.newChipColor,
            focus: $focus,
            focusValue: .newChip,
            onSubmit: {
                topBarVM.commitNewChipOrCancel(commitIfNonEmpty: true)
                env.focusView = .history
            },
            onCycleColor: {
                let nextIndex =
                    (topBarVM.newChipColorIndex + 1)
                        % CategoryChip.palette.count
                topBarVM.newChipColorIndex = nextIndex
            }
        )
        .onChange(of: env.focusView) {
            if env.focusView != .newChip {
                topBarVM.commitNewChipOrCancel(commitIfNonEmpty: true)
            }
        }
    }

    private var addChipButton: some View {
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
        .frame(width: 24, height: 24)
        .buttonStyle(.plain)
    }

    // MARK: - 键盘事件处理

    private func floatingKeyDownEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window === ClipFloatingWindowController.shared.window
        else {
            return event
        }

        let isInInputMode =
            env.focusView == .search || env.focusView == .newChip || env.focusView == .editChip

        if !isInInputMode,
           EventDispatcher.shared.handleTabNavigationShortcut(
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
                    focus = nil
                    env.focusView = .history
                }
                return nil
            }

            return event
        }

        if KeyCode.shouldTriggerSearch(for: event) {
            env.focusView = .search
            focus = .search
            return nil
        }

        return event
    }

    private func syncFocusFromEnv() {
        if env.focusView.requiresSystemFocus {
            Task { @MainActor in
                focus = env.focusView
            }
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
                editingView
            } else {
                normalView
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

    private var normalView: some View {
        Button(action: onTap) {
            HStack(spacing: Const.space4) {
                Text(chip.name)
                    .foregroundStyle(
                        isSelected ? .white : .primary.opacity(0.8)
                    )
            }
            .padding(.horizontal, Const.space10)
            .padding(.vertical, Const.space4)
            .background {
                RoundedRectangle(cornerRadius: Const.radius)
                    .fill(
                        isSelected
                            ? chip.isSystem ? .accentColor : chip.color
                            : .clear
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var editingView: some View {
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
        .onChange(of: env.focusView) {
            if env.focusView != .editChip {
                topBarVM.commitEditingChip()
            }
        }
    }

    private func handleDrop() -> Bool {
        guard let draggingId = env.draggingItemId else {
            return false
        }

        guard let item = pd.dataList.first(where: { $0.id == draggingId }) else {
            return false
        }

        if item.group == chip.id {
            return true
        }

        if let selectedChip = topBarVM.chips.first(where: { $0.id == topBarVM.selectedChipId }),
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
        alert.messageText = "删除『\(chip.name)』？"
        alert.informativeText = "删除『\(chip.name)』及其所属内容将无法恢复。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

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

#Preview {
    let env = AppEnvironment()
    FloatingHeaderView()
        .environment(env)
        .frame(width: 370, height: 90)
}
