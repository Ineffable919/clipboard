//
//  ChipView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import SwiftUI

struct ChipView: View {
    var isSelected: Bool
    var chip: CategoryChip

    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(PrefKey.backgroundType.rawValue)
    private var backgroundTypeRaw: Int = 0

    @FocusState.Binding var focus: FocusField?
    @Bindable var topBarVM: TopBarViewModel
    @State private var isTypeHovered: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var helpText: String = ""

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
                    onHoverChanged: { hovering in
                        isTypeHovered = hovering
                        if hovering {
                            Task {
                                await updateHelpText()
                            }
                        }
                    }
                )
            }
        }
        .help(helpText)
        .onDrop(
            of: ChipDropTypes.types,
            isTargeted: $isDropTargeted
        ) { _ in
            handleDrop()
        }
    }

    private var normalView: some View {
        HStack(spacing: Const.space6) {
            if chip.id == -1 {
                if #available(macOS 15.0, *) {
                    Image(
                        systemName:
                        "clock.arrow.trianglehead.counterclockwise.rotate.90"
                    )
                } else {
                    Image("clock.arrow.trianglehead.counterclockwise.rotate.90")
                }
            } else {
                Circle()
                    .fill(chip.color)
                    .frame(width: Const.space12, height: Const.space12)
                    .padding(Const.space2)
            }
            if focusHistory() {
                Text(chip.name)
            }
        }
        .padding(Const.chipPadding)
        .background {
            overlayColor()
        }
        .cornerRadius(Const.radius)
        .onHover { hovering in
            if chip.isSystem {
                isTypeHovered = hovering
                if hovering {
                    Task {
                        await updateHelpText()
                    }
                }
            }
        }
    }

    private func updateHelpText() async {
        let count: Int = if chip.id == -1 {
            pd.totalCount
        } else {
            await pd.getCountByGroup(groupId: chip.id)
        }

        let formattedCount = NumberFormatter.localizedString(
            from: NSNumber(value: count),
            number: .decimal
        )

        var shortcutText = ""
        if let prevInfo = HotKeyManager.shared.getHotKey(key: "previous_tab"),
           let nextInfo = HotKeyManager.shared.getHotKey(key: "next_tab"),
           prevInfo.isEnabled,
           nextInfo.isEnabled
        {
            let prevDisplay = prevInfo.shortcut.displayString
            let nextDisplay = nextInfo.shortcut.displayString
            shortcutText = "（\(prevDisplay)，\(nextDisplay)切换Tab）"
        }

        helpText = "\(formattedCount)条\(shortcutText)"
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

    @ViewBuilder
    private func overlayColor() -> some View {
        if !focusHistory() {
            Color.clear
        } else {
            overlayColorForHistory()
        }
    }

    private func overlayColorForHistory() -> Color {
        let backgroundType =
            BackgroundType(rawValue: backgroundTypeRaw) ?? .liquid

        if isSelected {
            return selectedColor(backgroundType: backgroundType)
        } else if isDropTargeted || isTypeHovered {
            return hoverColor(backgroundType: backgroundType)
        } else {
            return Color.clear
        }
    }

    private func selectedColor(backgroundType: BackgroundType) -> Color {
        if colorScheme == .dark {
            return Const.chooseDarkColor
        }

        if #available(macOS 26.0, *) {
            return backgroundType == .liquid
                ? Const.chooseLightColorLiquid
                : Const.chooseLightColorFrosted
        } else {
            return Const.chooseLightColorFrostedLow
        }
    }

    private func hoverColor(backgroundType: BackgroundType) -> Color {
        if colorScheme == .dark {
            return Const.hoverDarkColor
        }

        if #available(macOS 26.0, *) {
            return backgroundType == .liquid
                ? Const.hoverLightColorLiquid
                : Const.hoverLightColorFrosted
        } else {
            return Const.hoverLightColorFrostedLow
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

    private func focusHistory() -> Bool {
        !topBarVM.hasInput && env.focusView != .search
            && env.focusView != .filter
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
    @Previewable @State var topBarVM = TopBarViewModel()
    @Previewable @State var env = AppEnvironment()

    ChipViewPreviewWrapper(topBarVM: topBarVM, env: env)
}

private struct ChipViewPreviewWrapper: View {
    var topBarVM: TopBarViewModel
    var env: AppEnvironment
    @FocusState private var focus: FocusField?

    var body: some View {
        ChipView(
            isSelected: true,
            chip: topBarVM.chips[2],
            focus: $focus,
            topBarVM: topBarVM
        )
        .environment(env)
        .frame(width: 128, height: 32)
        .padding()
    }
}
