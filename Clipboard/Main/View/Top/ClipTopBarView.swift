//
//  ClipTopBarView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import Combine
import SwiftUI

struct TopBarView: View {
    @Bindable private var vm = ClipboardViewModel.shard
    @FocusState private var focus: FocusField?
    @State private var isIconHovered: Bool = false
    @State private var isPlusHovered: Bool = false
    @State private var syncingFocus = false

    var body: some View {
        GeometryReader { geo in
            let leading = max(0, floor(geo.size.width / 2 - 200))

            HStack(alignment: .center, spacing: 4) {
                Spacer().frame(width: leading)
                if vm.focusView == .search || !vm.query.isEmpty {
                    searchField
                } else {
                    searchIcon
                }
                typeView
                Spacer(minLength: Const.topBarHeight)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard vm.focusView != .history else { return }
                vm.focusView = .history
            }
            .onChange(of: focus) {
                guard !syncingFocus else { return }
                syncingFocus = true
                vm.focusView =
                    (focus == .search
                        ? .search : focus == .newChip ? .newChip : focus == .editChip ? .editChip : .history)
                syncingFocus = false
            }
            .onChange(of: vm.focusView) {
                guard !syncingFocus else { return }
                syncingFocus = true
                let desired: FocusField? =
                    (vm.focusView == .search
                        ? .search : vm.focusView == .newChip ? .newChip : vm.focusView == .editChip ? .editChip : nil)
                DispatchQueue.main.async {
                    focus = desired
                    syncingFocus = false
                }
                
                if vm.focusView != .editChip && vm.isEditingChip {
                    vm.commitEditingChip()
                }
            }
            .onChange(of: vm.query) { _, _ in
                vm.onSearchParametersChanged()
            }
            .onChange(of: vm.selectedChipId) { _, _ in
                vm.onSearchParametersChanged()
            }
        }
        .frame(height: Const.topBarHeight)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Const.iconHdSize, weight: .light))
                .foregroundColor(.gray)

            TextField("搜索...", text: $vm.query)
                .textFieldStyle(.plain)
                .focused($focus, equals: .search)

            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .padding(4)
        .frame(width: Const.topBarWidth)
        .background(.clear)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                .stroke(
                    focus == .search
                        ? Color.accentColor.opacity(0.4)
                        : Color.gray.opacity(0.4),
                    lineWidth: 3
                )
                .padding(-1)
        )
        .onTapGesture {
            focus = .search
        }
    }

    private var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: Const.iconHdSize, weight: .light))
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                    .fill(
                        isIconHovered ? Const.hoverColor : Color.clear
                    )
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isIconHovered = hovering
            }
            .onTapGesture {
                vm.focusView = .search
                DispatchQueue.main.async {
                    focus = .search
                }
            }
    }

    private var typeView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.chips) { chip in
                    ChipView(
                        isSelected: vm.selectedChipId == chip.id,
                        chip: chip
                    )
                    .onTapGesture {
                        vm.toggleChip(chip)
                        guard vm.focusView != .history else { return }
                        vm.focusView = .history
                    }
                }

                if vm.editingNewChip {
                    addChipView
                }
                plusIcon
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
        .frame(height: Const.topBarHeight)
        .onTapGesture {
            vm.focusView = .history
        }
    }

    private var addChipView: some View {
        EditableChip(
            name: $vm.newChipName,
            color: $vm.newChipColor,
            focus: $focus,
            onCommit: {
                vm.commitNewChipOrCancel(commitIfNonEmpty: true)
            },
            onCancel: {
                vm.commitNewChipOrCancel(commitIfNonEmpty: false)
            },
            onCycleColor: {
                var nextIndex =
                    (vm.newChipColorIndex + 1) % CategoryChip.palette.count
                if nextIndex == 0 {
                    nextIndex = 1
                }
                vm.newChipColorIndex = nextIndex
            }
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                focus = .newChip
            }
        }
        .onChange(of: vm.focusView) {
            if vm.focusView != .newChip {
                vm.commitNewChipOrCancel(commitIfNonEmpty: true)
            }
        }
    }

    private var plusIcon: some View {
        Image(systemName: "plus")
            .font(.system(size: Const.iconHdSize, weight: .light))
            .symbolRenderingMode(.hierarchical)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                    .fill(
                        isPlusHovered
                            ? Const.hoverColor : Color.clear
                    )
            )
            .onHover { hovering in
                isPlusHovered = hovering
            }
            .onTapGesture {
                if !vm.editingNewChip {
                    withAnimation(.easeOut(duration: 0.12)) {
                        vm.editingNewChip = true
                    }
                    focus = .newChip
                } else {
                    vm.commitNewChipOrCancel(commitIfNonEmpty: true)
                }
            }
    }
}

#Preview {
    TopBarView()
}
