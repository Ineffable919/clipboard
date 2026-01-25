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

    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(PrefKey.backgroundType.rawValue)
    private var backgroundTypeRaw: Int = 0

    @FocusState.Binding var focus: FocusField?
    @Bindable var topBarVM: TopBarViewModel
    @State private var isTypeHovered: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var helpText: String = ""

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
            of: ChipView.dropTypes,
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

// MARK: - AppKit Context Menu Helper

private struct ChipContextMenuHelper: NSViewRepresentable {
    let chip: CategoryChip
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onColorChange: (Int) -> Void
    let onHoverChanged: (Bool) -> Void

    func makeNSView(context _: Context) -> ChipContextMenuView {
        let view = ChipContextMenuView()
        view.chip = chip
        view.onEdit = onEdit
        view.onDelete = onDelete
        view.onColorChange = onColorChange
        view.onHoverChanged = onHoverChanged
        return view
    }

    func updateNSView(_ nsView: ChipContextMenuView, context _: Context) {
        nsView.chip = chip
        nsView.onEdit = onEdit
        nsView.onDelete = onDelete
        nsView.onColorChange = onColorChange
        nsView.onHoverChanged = onHoverChanged
    }
}

private final class ChipContextMenuView: NSView {
    var chip: CategoryChip?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onColorChange: ((Int) -> Void)?
    var onHoverChanged: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        if let trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with _: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with _: NSEvent) {
        onHoverChanged?(false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let currentEvent = NSApp.currentEvent,
              currentEvent.type == .rightMouseDown
        else {
            return nil
        }
        return super.hitTest(point)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let chip, !chip.isSystem else {
            super.rightMouseDown(with: event)
            return
        }

        let menu = NSMenu()

        let editItem = NSMenuItem(title: "编辑", action: #selector(editAction), keyEquivalent: "")
        editItem.target = self
        editItem.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
        menu.addItem(editItem)

        let deleteItem = NSMenuItem(title: "删除", action: #selector(deleteAction), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        menu.addItem(deleteItem)

        menu.addItem(.separator())

        let colorItem = NSMenuItem()
        colorItem.title = ""
        let colorView = ColorPaletteView(
            currentColorIndex: chip.colorIndex,
            onColorChange: { [weak self] index in
                menu.cancelTracking()
                self?.onColorChange?(index)
            }
        )
        colorItem.view = colorView
        menu.addItem(colorItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func editAction() {
        onEdit?()
    }

    @objc private func deleteAction() {
        onDelete?()
    }
}

private final class ColorPaletteView: NSView {
    private let currentColorIndex: Int
    private let onColorChange: (Int) -> Void

    init(currentColorIndex: Int, onColorChange: @escaping (Int) -> Void) {
        self.currentColorIndex = currentColorIndex
        self.onColorChange = onColorChange
        super.init(frame: .zero)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        let circleSize: CGFloat = 14
        let spacing: CGFloat = 12
        let padding: CGFloat = 16
        let colors = CategoryChip.palette

        let totalWidth = CGFloat(colors.count) * circleSize + CGFloat(colors.count - 1) * spacing + padding * 2
        let totalHeight = circleSize + padding * 2

        frame = NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight)

        for (index, color) in colors.enumerated() {
            let circleView = ColorCircleView(
                color: NSColor(color),
                isSelected: index == currentColorIndex,
                onTap: { [weak self] in
                    self?.onColorChange(index)
                }
            )
            circleView.frame = NSRect(
                x: padding + CGFloat(index) * (circleSize + spacing),
                y: padding,
                width: circleSize,
                height: circleSize
            )
            addSubview(circleView)
        }
    }
}

private final class ColorCircleView: NSView {
    private let color: NSColor
    private let isSelected: Bool
    private let onTap: () -> Void
    private var isHovered = false

    private var trackingArea: NSTrackingArea?

    init(color: NSColor, isSelected: Bool, onTap: @escaping () -> Void) {
        self.color = color
        self.isSelected = isSelected
        self.onTap = onTap
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        if let trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with _: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with _: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onTap()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(ovalIn: rect)

        color.setFill()
        path.fill()

        if isSelected || isHovered {
            NSColor.white.withAlphaComponent(0.8).setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }
}
