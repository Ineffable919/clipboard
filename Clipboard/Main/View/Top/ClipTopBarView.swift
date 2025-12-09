//
//  ClipTopBarView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import Combine
import SwiftUI

struct ClipTopBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppEnvironment.self) private var env
    @AppStorage(PrefKey.backgroundType.rawValue)
    private var backgroundTypeRaw: Int = 0
    @FocusState private var focus: FocusField?
    @State private var isIconHovered: Bool = false
    @State private var isPlusHovered: Bool = false
    @State private var syncingFocus = false

    var body: some View {
        GeometryReader { geo in
            let leading = max(0, floor(geo.size.width / 2 - 200))

            HStack(alignment: .center, spacing: Const.space4) {
                Spacer().frame(width: leading)
                if env.focusView == .search || !env.searchVM.query.isEmpty {
                    searchField
                } else {
                    searchIcon
                }
                typeView
                Spacer(minLength: Const.topBarHeight)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard env.focusView != .history else { return }
                env.focusView = .history
            }
            .onChange(of: focus) {
                guard !syncingFocus else { return }
                syncingFocus = true
                env.focusView = FocusField.fromOptional(focus)
                syncingFocus = false
            }
            .onChange(of: env.focusView) {
                guard !syncingFocus else { return }
                syncingFocus = true
                DispatchQueue.main.async {
                    focus = env.focusView.asOptional
                    syncingFocus = false
                }
                if env.focusView != .editChip, env.chipVM.isEditingChip {
                    env.chipVM.commitEditingChip()
                }
            }
            .onChange(of: env.searchVM.query) { _, _ in
                triggerSearchUpdate()
            }
            .onChange(of: env.chipVM.selectedChipId) { _, _ in
                triggerSearchUpdate()
            }
        }
        .frame(height: Const.topBarHeight)
    }

    private var searchField: some View {
        @Bindable var searchVM = env.searchVM
        return HStack(spacing: Const.space8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Const.iconHdSize, weight: .regular))
                .foregroundColor(.gray)

            TextField("搜索...", text: $searchVM.query)
                .textFieldStyle(.plain)
                .focused($focus, equals: .search)

            if !env.searchVM.query.isEmpty {
                Button {
                    env.searchVM.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .padding(Const.space6)
        .frame(width: Const.topBarWidth)
        .background(.clear)
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
        .contentShape(Rectangle())
        .onTapGesture {
            focus = .search
        }
    }

    private var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: Const.iconHdSize, weight: .regular))
            .padding(Const.space4)
            .background(
                RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                    .fill(isIconHovered ? hoverColor() : Color.clear)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isIconHovered = hovering
            }
            .onTapGesture {
                env.focusView = .search
                DispatchQueue.main.async {
                    focus = .search
                }
            }
    }

    private var typeView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Const.space8) {
                ForEach(env.chipVM.chips) { chip in
                    ChipView(
                        isSelected: env.chipVM.selectedChipId == chip.id,
                        chip: chip
                    )
                    .onTapGesture {
                        env.chipVM.toggleChip(chip)
                        guard env.focusView != .history else { return }
                        env.focusView = .history
                    }
                }

                if env.chipVM.editingNewChip {
                    addChipView
                }
                plusIcon
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
        .frame(height: Const.topBarHeight)
        .onTapGesture {
            env.focusView = .history
        }
    }

    private var addChipView: some View {
        @Bindable var chipVM = env.chipVM
        return EditableChip(
            name: $chipVM.newChipName,
            color: $chipVM.newChipColor,
            focus: $focus,
            onCommit: {
                chipVM.commitNewChipOrCancel(commitIfNonEmpty: true)
            },
            onCancel: {
                chipVM.commitNewChipOrCancel(commitIfNonEmpty: false)
            },
            onCycleColor: {
                var nextIndex =
                    (chipVM.newChipColorIndex + 1) % CategoryChip.palette.count
                if nextIndex == 0 {
                    nextIndex = 1
                }
                chipVM.newChipColorIndex = nextIndex
            }
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                focus = .newChip
            }
        }
        .onChange(of: env.focusView) {
            if env.focusView != .newChip {
                env.chipVM.commitNewChipOrCancel(commitIfNonEmpty: true)
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
                    .fill(isPlusHovered ? hoverColor() : Color.clear)
            )
            .onHover { hovering in
                isPlusHovered = hovering
            }
            .onTapGesture {
                if !env.chipVM.editingNewChip {
                    withAnimation(.easeOut(duration: 0.12)) {
                        env.chipVM.editingNewChip = true
                    }
                    focus = .newChip
                } else {
                    env.chipVM.commitNewChipOrCancel(commitIfNonEmpty: true)
                }
            }
    }

    private func triggerSearchUpdate() {
        env.searchVM.onSearchParametersChanged(
            typeFilter: env.chipVM.getTypeFilterForCurrentChip(),
            group: env.chipVM.getGroupFilterForCurrentChip(),
            selectedChipId: env.chipVM.selectedChipId
        )
    }

    private func hoverColor() -> Color {
        if #available(macOS 26.0, *) {
            let backgroundType = BackgroundType(rawValue: backgroundTypeRaw) ?? .liquid
            return colorScheme == .dark
                ? Const.hoverDarkColor
                : (backgroundType == .liquid ? Const.hoverLightColorLiquid : Const.hoverLightColorFrosted)
        } else {
            return colorScheme == .dark
                ? Const.hoverDarkColor
                : Const.hoverLightColorFrostedLow
        }
    }
}

#Preview {
    ClipTopBarView()
}
