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

    init(isSelected: Bool, chip: CategoryChip) {
        self.isSelected = isSelected
        self.chip = chip
    }

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(PrefKey.backgroundType.rawValue)
    private var backgroundTypeRaw: Int = 0
    @State private var isTypeHovered: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var syncingFocus = false
    @FocusState private var isTextFieldFocused: Bool
    @Bindable private var vm = ClipboardViewModel.shard

    private var isEditing: Bool {
        vm.editingChipId == chip.id
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
                    vm.startEditingChip(chip)
                } label: {
                    Label("编辑", systemImage: "pencil")
                }

                Button {
                    vm.isShowDel = true
                    showDelAlert(chip)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .onDrop(
            of: ChipView.dropTypes,
            isTargeted: $isDropTargeted,
        ) { providers in
            if chip.isSystem {
                return false
            }
            if vm.draggingItemId != nil {
                DispatchQueue.main.async {
                    handleDrop(providers: providers)
                }
                return true
            }
            return false
        }
    }

    private var normalView: some View {
        HStack(spacing: 6) {
            if chip.id == 1 {
                Image(
                    systemName:
                        "clock.arrow.trianglehead.counterclockwise.rotate.90"
                )
            } else {
                Circle()
                    .fill(chip.color)
                    .frame(width: Const.space12, height: Const.space12)
            }
            Text(chip.name)
                .font(.body)
        }
        .padding(
            EdgeInsets(
                top: Const.space4,
                leading: Const.space10,
                bottom: Const.space4,
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
    }

    private var editingView: some View {
        HStack(spacing: Const.space8) {
            Circle()
                .fill(vm.editingChipColor)
                .frame(width: Const.space12, height: Const.space12)
                .onTapGesture {
                    vm.cycleEditingChipColor()
                }

            TextField("", text: $vm.editingChipName)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isTextFieldFocused)
                .onSubmit {
                    vm.commitEditingChip()
                }
                .frame(minWidth: 54)
        }
        .padding(
            EdgeInsets(
                top: Const.space4,
                leading: Const.space10,
                bottom: Const.space4,
                trailing: Const.space10
            )
        ).background(
            RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                .fill(Color.secondary.opacity(0.08)),
        )
        .contentShape(
            RoundedRectangle(cornerRadius: Const.radius, style: .continuous),
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                vm.focusView = .editChip
                isTextFieldFocused = true
            }
        }
        .onChange(of: isTextFieldFocused) { _, isFocused in
            guard !syncingFocus else { return }
            syncingFocus = true
            if isFocused {
                vm.focusView = .editChip
            } else if vm.focusView == .editChip {
                vm.focusView = .history
            }
            syncingFocus = false
        }
        .onChange(of: vm.focusView) { _, newFocus in
            guard !syncingFocus else { return }
            syncingFocus = true
            if newFocus == .editChip, !isTextFieldFocused {
                DispatchQueue.main.async {
                    isTextFieldFocused = true
                }
            } else if newFocus != .editChip, isTextFieldFocused {
                isTextFieldFocused = false
            }
            syncingFocus = false
        }
    }

    @ViewBuilder
    private func overlayColor() -> some View {
        let backgroundType =
            BackgroundType(rawValue: backgroundTypeRaw) ?? .liquid
        if isSelected {
            if #available(macOS 26.0, *) {
                colorScheme == .dark
                    ? Const.chooseDarkColor
                    : (backgroundType == .liquid
                        ? Const.chooseLightColorLiquid
                        : Const.chooseLightColorFrosted)
            } else {
                colorScheme == .dark
                    ? Const.chooseDarkColor
                    : Const.chooseLightColorFrostedLow
            }
        } else if isDropTargeted || isTypeHovered {
            if #available(macOS 26.0, *) {
                colorScheme == .dark
                    ? Const.hoverDarkColor
                    : (backgroundType == .liquid
                        ? Const.hoverLightColorLiquid
                        : Const.hoverLightColorFrosted)
            } else {
                colorScheme == .dark
                    ? Const.hoverDarkColor
                    : Const.hoverLightColorFrostedLow
            }
        } else {
            Color.clear
        }
    }

    private func handleDrop(providers _: [NSItemProvider]) {
        guard let draggingId = vm.draggingItemId else {
            return
        }

        defer {
            vm.draggingItemId = nil
        }

        do {
            try PasteDataStore.main.updateItemGroup(
                itemId: draggingId,
                groupId: chip.id,
            )
        } catch {
            log.error("更新卡片 group 失败: \(error)")
        }
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
                self.vm.isShowDel = false
            }

            guard response == .alertFirstButtonReturn
            else {
                return
            }

            vm.removeChip(chip)
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
    let vm = ClipboardViewModel.shard
    ChipView(
        isSelected: true,
        chip: vm.chips[0],
    )
    .frame(width: 128, height: 32)
}
