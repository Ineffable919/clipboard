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
    @EnvironmentObject private var env: AppEnvironment
    @AppStorage(PrefKey.backgroundType.rawValue)
    private var backgroundTypeRaw: Int = 0
    @FocusState private var focus: FocusField?
    @State private var topBarVM = TopBarViewModel()
    @State private var isIconHovered: Bool = false
    @State private var isPlusHovered: Bool = false
    @State private var isFilterPopoverPresented: Bool = false

    var body: some View {
        GeometryReader { geo in
            let leading = leadingSpace(geo: geo)

            HStack(alignment: .center, spacing: Const.space4) {
                Color.clear
                    .frame(width: leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusHistory()
                    }
                if env.focusView == .search || env.focusView == .filter
                    || topBarVM.hasInput
                {
                    searchField
                } else {
                    searchIcon
                }
                typeView
                Spacer(minLength: Const.space14)
            }
        }
        .frame(height: Const.topBarHeight)
        .onChange(of: env.focusView) {
            switch env.focusView {
            case .search:
                DispatchQueue.main.async {
                    focus = .search
                }
            case .newChip:
                DispatchQueue.main.async {
                    focus = .newChip
                }
            case .editChip:
                DispatchQueue.main.async {
                    focus = .editChip
                }
            case .history, .filter, .popover:
                focus = nil
            }
        }
        .onAppear {
            EventDispatcher.shared.registerHandler(
                matching: .keyDown,
                key: "top",
                handler: topKeyDownEvent(_:),
            )
        }
    }

    private var searchField: some View {
        HStack(spacing: Const.space8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Const.iconHdSize, weight: .regular))
                .foregroundColor(.black).opacity(0.6)

            TextField(topBarVM.hasInput ? "" : "搜索", text: $topBarVM.query)
                .textFieldStyle(.plain)
                .focused($focus, equals: .search)
                .onChange(of: focus) {
                    if focus == .search, env.focusView != .search {
                        env.focusView = .search
                    }
                }

            if !topBarVM.query.isEmpty {
                Button {
                    topBarVM.clearInput()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14.0, weight: .medium))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            Button {
                toggleFilterPopover()
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: Const.iconHdSize, weight: .regular))
                    .foregroundColor(.black).opacity(0.6)
            }
            .buttonStyle(.plain)
            .frame(width: 20.0, height: 20.0)
            .focusEffectDisabled()
            .popover(isPresented: $isFilterPopoverPresented) {
                FilterPopoverView(topBarVM: topBarVM)
            }
        }
        .padding(Const.space6)
        .frame(width: Const.topBarWidth)
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
            }
    }

    private var typeView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Const.space8) {
                ForEach(topBarVM.chips) { chip in
                    ChipView(
                        isSelected: topBarVM.selectedChipId == chip.id,
                        chip: chip,
                        focus: $focus,
                        topBarVM: topBarVM
                    )
                    .onTapGesture {
                        topBarVM.clearInput()
                        topBarVM.toggleChip(chip)
                        guard env.focusView != .history else { return }
                        env.focusView = .history
                    }
                }

                if topBarVM.editingNewChip {
                    addChipView
                }
                if env.focusView != .search, env.focusView != .filter {
                    plusIcon
                }
            }
            .padding(.vertical, Const.space12)
            .padding(.horizontal, Const.space4)
        }
        .frame(height: Const.topBarHeight)
        .onTapGesture {
            focusHistory()
        }
    }

    private var addChipView: some View {
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

    private var plusIcon: some View {
        Image(systemName: "plus")
            .font(.system(size: Const.iconHdSize, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .padding(Const.space4)
            .background(
                RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                    .fill(isPlusHovered ? hoverColor() : Color.clear)
            )
            .onHover { hovering in
                isPlusHovered = hovering
            }
            .onTapGesture {
                if !topBarVM.editingNewChip {
                    topBarVM.editingNewChip = true

                    focus = .newChip
                } else {
                    topBarVM.commitNewChipOrCancel(commitIfNonEmpty: true)
                }
                env.focusView = .newChip
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
            || topBarVM.hasInput
        {
            return max(0, floor(geo.size.width / 2 - 200))
        }
        return max(0, floor(geo.size.width / 2 - 120))
    }

    private func topKeyDownEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window === ClipMainWindowController.shared.window
        else {
            return event
        }

        if KeyCode.shouldTriggerSearch(for: event) {
            if env.focusView == .editChip || env.focusView == .newChip {
                return event
            }
            env.focusView = .search
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
            if topBarVM.hasInput, env.focusView == .search {
                topBarVM.clearInput()
                return nil
            }
            if !topBarVM.hasInput, env.focusView == .search {
                env.focusView = .history
                return nil
            }
            if env.focusView == .filter {
                if isFilterPopoverPresented {
                    isFilterPopoverPresented.toggle()
                }
                env.focusView = .search
                return nil
            }
        }

        return event
    }

    private func focusHistory() {
        focus = nil
        if isFilterPopoverPresented {
            isFilterPopoverPresented = false
        }
        env.focusView = .history
    }

    private func toggleFilterPopover() {
        isFilterPopoverPresented.toggle()
        if isFilterPopoverPresented {
            env.focusView = .filter
            focus = nil
        } else {
            env.focusView = .search
            DispatchQueue.main.async {
                focus = .search
            }
        }
    }
}

#Preview {
    @Previewable @StateObject var env = AppEnvironment()
    ClipTopBarView()
        .environmentObject(env)
        .frame(width: 1000.0, height: 50.0)
}
