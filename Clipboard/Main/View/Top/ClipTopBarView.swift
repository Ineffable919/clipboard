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
    @State private var isFilterPopoverPresented: Bool = false
    @State private var syncingFocus = false

    var body: some View {
        GeometryReader { geo in
            let leading = leadingSpace(geo: geo)

            HStack(alignment: .center, spacing: Const.space4) {
                Spacer().frame(width: leading)
                if env.focusView == .search || env.focusView == .filter
                    || !env.topBarVM.query.isEmpty
                {
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
                guard !isFilterPopoverPresented else { return }
                syncingFocus = true
                env.focusView = FocusField.fromOptional(focus)
                syncingFocus = false
            }
            .onChange(of: env.focusView) {
                guard !syncingFocus else { return }
                guard env.focusView != .filter else { return }
                syncingFocus = true
                DispatchQueue.main.async {
                    focus = env.focusView.asOptional
                    syncingFocus = false
                }
                if env.focusView != .editChip, env.topBarVM.isEditingChip {
                    env.topBarVM.commitEditingChip()
                }
            }
        }
        .frame(height: Const.topBarHeight)
    }

    private var searchField: some View {
        @Bindable var topBarVM = env.topBarVM
        return HStack(spacing: Const.space8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Const.iconHdSize, weight: .regular))
                .foregroundColor(.black).opacity(0.6)

            TextField("搜索...", text: $topBarVM.query)
                .textFieldStyle(.plain)
                .focused($focus, equals: .search)

            if !env.topBarVM.query.isEmpty {
                Button {
                    env.topBarVM.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }

            Button {
                isFilterPopoverPresented.toggle()
                if isFilterPopoverPresented {
                    focus = nil
                    env.focusView = .filter
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 14.0, weight: .medium))
            }
            .buttonStyle(.plain)
            .frame(width: 20.0, height: 20.0)
            .contentShape(Rectangle())
            .popover(isPresented: $isFilterPopoverPresented) {
                FilterPopoverView(topBarVM: env.topBarVM)
                    .environment(env)
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
                ForEach(env.topBarVM.chips) { chip in
                    ChipView(
                        isSelected: env.topBarVM.selectedChipId == chip.id,
                        chip: chip
                    )
                    .onTapGesture {
                        env.topBarVM.clearAllFilters()
                        env.topBarVM.toggleChip(chip)
                        guard env.focusView != .history else { return }
                        env.focusView = .history
                    }
                }

                if env.topBarVM.editingNewChip {
                    addChipView
                }
                if env.focusView != .search && env.focusView != .filter {
                    plusIcon
                }
            }
            .padding(.vertical, Const.space12)
            .padding(.horizontal, Const.space4)
        }
        .frame(height: Const.topBarHeight)
        .onTapGesture {
            env.focusView = .history
        }
    }

    private var addChipView: some View {
        @Bindable var topBarVM = env.topBarVM
        return EditableChip(
            name: $topBarVM.newChipName,
            color: $topBarVM.newChipColor,
            focus: $focus,
            onCommit: {
                topBarVM.commitNewChipOrCancel(commitIfNonEmpty: true)
            },
            onCancel: {
                topBarVM.commitNewChipOrCancel(commitIfNonEmpty: false)
            },
            onCycleColor: {
                var nextIndex =
                    (topBarVM.newChipColorIndex + 1)
                        % CategoryChip.palette.count
                if nextIndex == 0 {
                    nextIndex = 1
                }
                topBarVM.newChipColorIndex = nextIndex
            }
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                focus = .newChip
            }
        }
        .onChange(of: env.focusView) {
            if env.focusView != .newChip {
                env.topBarVM.commitNewChipOrCancel(commitIfNonEmpty: true)
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
                if !env.topBarVM.editingNewChip {
                    withAnimation(.easeOut(duration: 0.2)) {
                        env.topBarVM.editingNewChip = true
                    }
                    focus = .newChip
                } else {
                    env.topBarVM.commitNewChipOrCancel(commitIfNonEmpty: true)
                }
            }
    }

    private func hoverColor() -> Color {
        if #available(macOS 26.0, *) {
            let backgroundType =
                BackgroundType(rawValue: backgroundTypeRaw) ?? .liquid
            return colorScheme == .dark
                ? Const.hoverDarkColor
                : (backgroundType == .liquid
                    ? Const.hoverLightColorLiquid
                    : Const.hoverLightColorFrosted)
        } else {
            return colorScheme == .dark
                ? Const.hoverDarkColor
                : Const.hoverLightColorFrostedLow
        }
    }

    private func leadingSpace(geo: GeometryProxy) -> CGFloat {
        if env.focusView == .search || env.focusView == .filter
            || !env.topBarVM.query.isEmpty
        {
            return max(0, floor(geo.size.width / 2 - 200))
        }
        return max(0, floor(geo.size.width / 2 - 120))
    }
}

#Preview {
    ClipTopBarView()
}
