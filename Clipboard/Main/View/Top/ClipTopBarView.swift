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
                    let hasInput = env.focusView == .search || env.focusView == .filter || topBarVM.hasInput
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
            SettingsMenu(topBarVM: topBarVM)
        }
        .overlay(alignment: .leading) {
            if topBarVM.isPaused {
                pauseIndicator
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

    private var pauseIndicator: some View {
        Button {
            topBarVM.resumePasteboard()
        } label: {
            HStack(spacing: Const.space6) {
                Image(systemName: "pause.fill")
                    .font(.system(size: Const.space10, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 18.0, height: 18.0)
                    .background(.orange, in: .circle)
                Text(topBarVM.formattedRemainingTime)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.leading, Const.space6)
            .padding(.trailing, Const.space10)
            .padding(.vertical, Const.space6)
            .background(
                .ultraThinMaterial,
                in: .capsule
            )
            .overlay(
                Capsule()
                    .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.leading, Const.space8)
        .buttonStyle(.plain)
        .help("点击恢复记录")
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
                    lineWidth: 3.5,
                )
                .padding(-1),
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
                    .fill(isIconHovered ? hoverColor() : Color.clear),
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
                        topBarVM: topBarVM,
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
            },
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
                    .fill(isPlusHovered ? hoverColor() : Color.clear),
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

    private func handleTabNavigationShortcut(_ event: NSEvent) -> Bool {
        guard let previousTabInfo = HotKeyManager.shared.getHotKey(key: "previous_tab"),
              let nextTabInfo = HotKeyManager.shared.getHotKey(key: "next_tab")
        else {
            return false
        }

        let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let eventModifiers = event.modifierFlags.intersection(relevantModifiers)

        if previousTabInfo.isEnabled,
           event.keyCode == previousTabInfo.shortcut.keyCode,
           eventModifiers == previousTabInfo.shortcut.modifiers.intersection(relevantModifiers)
        {
            topBarVM.selectPreviousChip()
            return true
        }

        if nextTabInfo.isEnabled,
           event.keyCode == nextTabInfo.shortcut.keyCode,
           eventModifiers == nextTabInfo.shortcut.modifiers.intersection(relevantModifiers)
        {
            topBarVM.selectNextChip()
            return true
        }

        return false
    }

    private func topKeyDownEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window === ClipMainWindowController.shared.window
        else {
            return event
        }

        let isInInputMode = env.focusView == .search
            || env.focusView == .newChip
            || env.focusView == .editChip
            || env.focusView == .popover

        if !isInInputMode, handleTabNavigationShortcut(event) {
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

        if event.keyCode == KeyCode.escape {}

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

struct SettingsMenu: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(PrefKey.backgroundType.rawValue)
    private var backgroundTypeRaw: Int = 0
    @State private var isHovered: Bool = false
    @State private var updateManager = UpdateManager.shared

    var topBarVM: TopBarViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "ellipsis")
                .font(.system(size: Const.iconHdSize, weight: .regular))
                .padding(.horizontal, Const.space6)
                .padding(.vertical, Const.space10)
                .background(
                    RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                        .fill(isHovered ? hoverColor() : Color.clear)
                )
                .onHover { hovering in
                    isHovered = hovering
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showNativeMenu()
                }

            if updateManager.hasUpdate {
                Circle()
                    .fill(.red)
                    .frame(width: 6.0, height: 6.0)
                    .offset(x: -Const.space4, y: Const.space4)
            }
        }
        .padding(.trailing)
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

    private func showNativeMenu() {
        let menu = NSMenu()

        if updateManager.hasUpdate {
            let newVersionItem = NSMenuItem(
                title: "检测到新版本 \(updateManager.availableVersion ?? "")",
                action: #selector(MenuActions.checkForUpdates),
                keyEquivalent: ""
            )
            newVersionItem.target = MenuActions.shared
            if let image = NSImage(
                systemSymbolName: "arrow.up.circle.dotted",
                accessibilityDescription: nil
            ) {
                let config = NSImage.SymbolConfiguration(
                    pointSize: 16.0,
                    weight: .semibold
                )
                image.isTemplate = true
                newVersionItem.image = image.withSymbolConfiguration(config)
            }
            menu.addItem(newVersionItem)
            menu.addItem(NSMenuItem.separator())
        }

        let settingsItem = NSMenuItem(
            title: "设置...",
            action: #selector(MenuActions.openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = MenuActions.shared
        settingsItem.image = NSImage(
            systemSymbolName: "gearshape",
            accessibilityDescription: nil
        )
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(
            title: "检查更新",
            action: #selector(MenuActions.checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = MenuActions.shared
        updateItem.image = NSImage(
            systemSymbolName: "arrow.clockwise",
            accessibilityDescription: nil
        )
        menu.addItem(updateItem)

        let helpItem = NSMenuItem(
            title: "帮助",
            action: #selector(MenuActions.invokeHelp),
            keyEquivalent: ""
        )
        helpItem.target = MenuActions.shared
        helpItem.image = NSImage(
            systemSymbolName: "questionmark.circle",
            accessibilityDescription: nil
        )
        menu.addItem(helpItem)

        menu.addItem(NSMenuItem.separator())

        let pauseItem = NSMenuItem(
            title: topBarVM.pauseMenuTitle,
            action: nil,
            keyEquivalent: ""
        )
        pauseItem.image = NSImage(
            systemSymbolName: "pause.circle",
            accessibilityDescription: nil
        )

        let pauseSubmenu = NSMenu()

        if topBarVM.isPaused {
            let resumeItem = NSMenuItem(
                title: "恢复",
                action: #selector(MenuActions.resumePasteboard),
                keyEquivalent: ""
            )
            resumeItem.target = MenuActions.shared
            resumeItem.image = NSImage(
                systemSymbolName: "play.circle",
                accessibilityDescription: nil
            )
            pauseSubmenu.addItem(resumeItem)
            pauseSubmenu.addItem(NSMenuItem.separator())
        } else {
            let pauseIndefiniteItem = NSMenuItem(
                title: "暂停",
                action: #selector(MenuActions.pauseIndefinitely),
                keyEquivalent: ""
            )
            pauseIndefiniteItem.target = MenuActions.shared
            pauseIndefiniteItem.image = NSImage(
                systemSymbolName: "pause.circle",
                accessibilityDescription: nil
            )
            pauseSubmenu.addItem(pauseIndefiniteItem)

            pauseSubmenu.addItem(NSMenuItem.separator())
        }

        let pause15Item = NSMenuItem(
            title: "暂停 15 分钟",
            action: #selector(MenuActions.pause15Minutes),
            keyEquivalent: ""
        )
        pause15Item.target = MenuActions.shared
        pause15Item.image = symbolImage(number: 15)
        pauseSubmenu.addItem(pause15Item)

        let pause30Item = NSMenuItem(
            title: "暂停 30 分钟",
            action: #selector(MenuActions.pause30Minutes),
            keyEquivalent: ""
        )
        pause30Item.target = MenuActions.shared
        pause30Item.image = symbolImage(number: 30)
        pauseSubmenu.addItem(pause30Item)

        let pause1hItem = NSMenuItem(
            title: "暂停 1 小时",
            action: #selector(MenuActions.pause1Hour),
            keyEquivalent: ""
        )
        pause1hItem.target = MenuActions.shared
        pause1hItem.image = symbolImage(number: 1)
        pauseSubmenu.addItem(pause1hItem)

        let pause3hItem = NSMenuItem(
            title: "暂停 3 小时",
            action: #selector(MenuActions.pause3Hours),
            keyEquivalent: ""
        )
        pause3hItem.target = MenuActions.shared
        pause3hItem.image = symbolImage(number: 3)
        pauseSubmenu.addItem(pause3hItem)

        let pause8hItem = NSMenuItem(
            title: "暂停 8 小时",
            action: #selector(MenuActions.pause8Hours),
            keyEquivalent: ""
        )
        pause8hItem.target = MenuActions.shared
        pause8hItem.image = symbolImage(number: 8)
        pauseSubmenu.addItem(pause8hItem)

        pauseItem.submenu = pauseSubmenu
        menu.addItem(pauseItem)

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.shared.terminate),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSView())
        }
    }

    private func symbolImage(number: Int) -> NSImage? {
        NSImage(
            systemSymbolName: "\(number).circle",
            accessibilityDescription: nil
        )
    }
}

class MenuActions: NSObject {
    static let shared = MenuActions()

    @objc func openSettings() {
        SettingWindowController.shared.toggleWindow()
    }

    @objc func checkForUpdates() {
        AppDelegate.shared?.updaterController.checkForUpdates(nil)
    }

    @objc func invokeHelp() {
        if let url = URL(
            string:
            "https://github.com/Ineffable919/clipboard/blob/master/README.md"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 暂停功能

    @objc func resumePasteboard() {
        PasteBoard.main.resume()
    }

    @objc func pause15Minutes() {
        PasteBoard.main.pause(for: 15 * 60)
    }

    @objc func pause30Minutes() {
        PasteBoard.main.pause(for: 30 * 60)
    }

    @objc func pause1Hour() {
        PasteBoard.main.pause(for: 60 * 60)
    }

    @objc func pause3Hours() {
        PasteBoard.main.pause(for: 3 * 60 * 60)
    }

    @objc func pause8Hours() {
        PasteBoard.main.pause(for: 8 * 60 * 60)
    }

    @objc func pauseIndefinitely() {
        PasteBoard.main.pause()
    }
}

#Preview {
    @Previewable @State var env = AppEnvironment()
    ClipTopBarView()
        .environment(env)
        .frame(width: 1000.0, height: 50.0)
}
