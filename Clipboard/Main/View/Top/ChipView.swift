//
//  ChipView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import SwiftUI
import UniformTypeIdentifiers

struct ChipView: View {
    var isSelected: Bool
    var chip: CategoryChip

    init(isSelected: Bool, chip: CategoryChip) {
        self.isSelected = isSelected
        self.chip = chip
    }

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
                    vm.removeChip(chip)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .onDrop(
            of: [UTType.clipType.identifier],
            isTargeted: $isDropTargeted
        ) { providers in
            if chip.isSystem {
                return false
            }
            handleDrop(providers: providers)
            return true
        }
    }

    private var normalView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(chip.color)
                .frame(width: 12, height: 12)
            Text(chip.name)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        .background {
            overlayColor()
        }
        .cornerRadius(Const.radius)
        .onHover { hovering in
            isTypeHovered = hovering
        }
    }

    private var editingView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(vm.editingChipColor)
                .frame(width: 12, height: 12)
                .onTapGesture {
                    vm.cycleEditingChipColor()
                }

            TextField("", text: $vm.editingChipName)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .textSelection(.disabled)
                .focused($isTextFieldFocused)
                .onSubmit {
                    vm.commitEditingChip()
                }
                .frame(minWidth: 54)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            if newFocus == .editChip && !isTextFieldFocused {
                DispatchQueue.main.async {
                    isTextFieldFocused = true
                }
            } else if newFocus != .editChip && isTextFieldFocused {
                isTextFieldFocused = false
            }
            syncingFocus = false
        }
    }

    @ViewBuilder
    private func overlayColor() -> some View {
        if isSelected {
            Const.chooseColor
        } else if isDropTargeted || isTypeHovered {
            Const.hoverColor
        } else {
            Color.clear
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(
                UTType.clipType.identifier
            ) {
                provider.loadDataRepresentation(
                    forTypeIdentifier: UTType.clipType.identifier
                ) { data, error in
                    if error != nil {
                        return
                    }
                    Task { @MainActor in
                        handleDropData(data: data)
                    }
                }
            }
        }
    }

    private func handleDropData(data: Data?) {
        if let data = data {
            let id = data.withUnsafeBytes { $0.load(as: Int.self) }
            do {
                try PasteDataStore.main.updateItemGroup(
                    itemId: Int64(id),
                    groupId: chip.id
                )
            } catch {
                log.error("更新卡片 group 失败: \(error)")
            }
        }
    }
}

#Preview {
    ChipView(
        isSelected: true,
        chip: CategoryChip(id: 11, name: "收藏", color: .green, isSystem: false)
    )
    .frame(width: 128, height: 32)
}
