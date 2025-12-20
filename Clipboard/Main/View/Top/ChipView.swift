//
//  ChipView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import SwiftUI
import UniformTypeIdentifiers

struct ChipView: View {
    private static let dropTypes: [UTType] = [
        .text,
        .rtf,
        .rtfd,
        .fileURL,
        .png,
        .tiff,
        .data,
    ]

    var isSelected: Bool
    var chip: CategoryChip

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(PrefKey.backgroundType.rawValue)
    private var backgroundTypeRaw: Int = 0

    @FocusState.Binding var focus: FocusField?
    @Bindable var topBarVM: TopBarViewModel
    @State private var isTypeHovered: Bool = false
    @State private var isDropTargeted: Bool = false

    private var pd: PasteDataStore { PasteDataStore.main }

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
        .contextMenu {
            if !chip.isSystem {
                Button {
                    topBarVM.startEditingChip(chip)
                    env.focusView = .editChip
                } label: {
                    Label("编辑", systemImage: "pencil")
                }

                Button {
                    env.isShowDel = true
                    showDelAlert(chip)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .onDrop(
            of: ChipView.dropTypes,
            isTargeted: $isDropTargeted,
        ) { _ in
            if chip.isSystem {
                return false
            }
            if env.draggingItemId != nil {
                return handleDrop()
            }
            return false
        }
    }

    private var normalView: some View {
        HStack(spacing: Const.space6) {
            if chip.id == 1 {
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
            if env.focusView != .search, env.focusView != .filter {
                Text(chip.name)
                    .font(.body)
            }
        }
        .padding(
            EdgeInsets(
                top: Const.space6,
                leading: Const.space10,
                bottom: Const.space6,
                trailing: Const.space10
            )
        )
        .background {
            overlayColor()
        }
        .cornerRadius(Const.radius)
        .onHover { hovering in
            isTypeHovered = hovering
        }
        .help(chip.id == 1 ? "\(PasteDataStore.main.totalCount)条" : "")
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
        if env.focusView != .history {
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

        if let item = pd.dataList.first(where: { $0.id == draggingId }) {
            if item.group == chip.id { return false }
        }

        defer {
            env.draggingItemId = nil
        }

        do {
            try PasteDataStore.main.updateItemGroup(
                itemId: draggingId,
                groupId: chip.id,
            )
        } catch {
            log.error("更新卡片 group 失败: \(error)")
            return false
        }
        return true
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
                    completionHandler: handleResponse,
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
    @Previewable @StateObject var env = AppEnvironment()

    ChipViewPreviewWrapper(topBarVM: topBarVM, env: env)
}

private struct ChipViewPreviewWrapper: View {
    var topBarVM: TopBarViewModel
    var env: AppEnvironment
    @FocusState private var focus: FocusField?

    var body: some View {
        ChipView(
            isSelected: true,
            chip: topBarVM.chips[0],
            focus: $focus,
            topBarVM: topBarVM
        )
        .environmentObject(env)
        .frame(width: 128, height: 32)
    }
}
