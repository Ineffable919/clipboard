//
//  ClipTopBarView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import Combine
import Sparkle
import SwiftUI

struct ClipTopBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppEnvironment.self) private var env
    @AppStorage(PrefKey.backgroundType.rawValue)
    private var backgroundTypeRaw: Int = 0
    @FocusState private var focus: FocusField?
    @State private var topBarVM = TopBarViewModel()
    @State private var isIconHovered: Bool = false
    @State private var isPlusHovered: Bool = false
    @State private var showFilter: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: Const.space4) {
            Color.clear
                .containerRelativeFrame(.horizontal) { width, _ in
                    let hasInput =
                        env.focusView == .search || env.focusView == .filter
                            || topBarVM.hasInput
                    return max(0, floor(width / 2 - (hasInput ? 200 : 120)))
                }
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
            Spacer()
            SettingsMenuView(topBarVM: topBarVM)
                .padding(.trailing)
        }
        .overlay(alignment: .leading) {
            if topBarVM.isPaused {
                PauseIndicatorView(topBarVM: topBarVM)
                    .padding(.leading, Const.space8)
            }
        }
        .frame(height: Const.topBarHeight)
        .onChange(of: env.focusView) {
            syncFocusFromEnv()
        }
        .onAppear {
            EventDispatcher.shared.registerHandler(
                matching: .keyDown,
                key: "top",
                handler: topKeyDownEvent(_:)
            )
            topBarVM.startPauseDisplayTimer()
        }
    }

    private var searchField: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Const.iconHdSize, weight: .regular))
                .foregroundStyle(.primary.opacity(0.8))
                .padding(.horizontal, Const.space6)

            inputTagView

            if topBarVM.hasInput {
                Button {
                    topBarVM.clearInput()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Const.iconHdSize, weight: .regular))
                        .foregroundStyle(.primary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            filterIcon
        }
        .padding(Const.space4)
        .frame(width: Const.topBarWidth, height: 32.0)
        .overlay(
            RoundedRectangle(cornerRadius: Const.topRadius, style: .continuous)
                .stroke(
                    focus == .search
                        ? Color.accentColor.opacity(0.4)
                        : Color.gray.opacity(0.4),
                    lineWidth: 3.5
                )
                .padding(-1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            env.focusView = .search
        }
        .task {
            await topBarVM.loadAppPathCache()
        }
    }

    private var inputTagView: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    inputContent(proxy: proxy)
                        .frame(
                            minWidth: geo.size.width,
                            minHeight: geo.size.height,
                            alignment: .leading
                        )
                }
                .onChange(of: topBarVM.tags.count) {
                    proxy.scrollTo("textfield", anchor: .trailing)
                }
                .onChange(of: topBarVM.query) {
                    proxy.scrollTo("textfield", anchor: .trailing)
                }
            }
        }
    }

    private func inputContent(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: Const.space6) {
            ForEach(topBarVM.tags) { tag in
                TagView(tag: tag) {
                    topBarVM.removeTag(tag)
                }
            }
            TextField(
                topBarVM.hasInput ? "" : "搜索",
                text: $topBarVM.query
            )
            .textFieldStyle(.plain)
            .focused($focus, equals: .search)
            .id("textfield")
            .autoScrollOnIMEInput {
                proxy.scrollTo("textfield", anchor: .trailing)
            }
            .onChange(of: focus) {
                if focus == .search, env.focusView != .search {
                    env.focusView = .search
                }
            }
        }
    }

    private var filterIcon: some View {
        Button {
            toggleFilterPopover()
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: Const.iconHdSize, weight: .regular))
                .foregroundStyle(.primary.opacity(0.8))
                .frame(width: 24, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showFilter) {
            FilterPopoverView(topBarVM: topBarVM)
                .onDisappear {
                    handleFilterDismiss()
                }
        }
    }

    private var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: Const.iconHdSize, weight: .regular))
            .padding(Const.space6)
            .background(
                RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                    .fill(isIconHovered ? hoverColor() : Color.clear)
            )
            .onHover { hovering in
                isIconHovered = hovering
            }
            .contentShape(Rectangle())
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
                if isFocusHistory {
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
            .padding(Const.space6)
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

    private func topKeyDownEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window === ClipMainWindowController.shared.window
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
                if topBarVM.hasInput, env.focusView == .search {
                    topBarVM.clearInput()
                    return nil
                }
                if !topBarVM.hasInput, env.focusView == .search {
                    env.focusView = .history
                    return nil
                }
                if env.focusView == .filter {
                    if showFilter {
                        showFilter.toggle()
                    }
                    env.focusView = .search
                    return nil
                }
                if env.focusView == .popover {
                    return event
                }
            }

            if event.keyCode == KeyCode.delete, env.focusView == .search {
                if !topBarVM.query.isEmpty {
                    return event
                }
                if topBarVM.hasActiveFilters {
                    topBarVM.removeLastFilter()
                    return nil
                }
            }

            return event
        }

        if KeyCode.shouldTriggerSearch(for: event) {
            env.focusView = .search
            return nil
        }
        return event
    }

    private var isFocusHistory: Bool {
        !topBarVM.hasInput && env.focusView != .search
            && env.focusView != .filter
    }

    private func focusHistory() {
        focus = nil
        if showFilter {
            showFilter = false
        }
        env.focusView = .history
    }

    private func syncFocusFromEnv() {
        if env.focusView.requiresSystemFocus {
            Task { @MainActor in
                focus = env.focusView
            }
        }
    }

    private func toggleFilterPopover() {
        if showFilter {
            showFilter = false
        } else {
            showFilter = true
            focus = nil
            env.focusView = .filter
        }
    }

    private func handleFilterDismiss() {
        if !showFilter {
            if env.focusView == .filter {
                focus = .search
            }
        }
    }
}

#Preview {
    @Previewable @State var env = AppEnvironment()
    ClipTopBarView()
        .environment(env)
        .frame(width: 1000.0, height: 50.0)
}
