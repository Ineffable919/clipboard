//
//  ChipButton.swift
//  Clipboard
//
//  Created by crown on 2026/4/9.
//

import AppKit
import SnapKit
import SwiftUI

final class ChipButton: NSView, NSTextFieldDelegate {
    private let haloInset: CGFloat = 4

    struct Config {
        let chip: CategoryChip
        var isSelected: Bool
        var dotMode: Bool = false
        var compact: Bool = false
        var isEditing: Bool = false
        var editingName: String = ""
        var editingColorIndex: Int = 0
        var action: () -> Void
        var onEdit: (() -> Void)?
        var onDelete: (() -> Void)?
        var onColorChange: ((Int) -> Void)?
        var onEditingNameChange: ((String) -> Void)?
        var onEditingSubmit: (() -> Void)?
        var onEditingCancel: (() -> Void)?
        var onEditingFocusChange: ((Bool) -> Void)?
        var onDrop: ((PasteboardModel) -> Bool)?

        fileprivate var iconContainerSize: CGFloat {
            compact ? 14 : 16
        }

        fileprivate var smallIconPt: CGFloat {
            compact ? 10 : 12
        }

        fileprivate var labelFontSize: CGFloat {
            compact ? NSFont.smallSystemFontSize : NSFont.systemFontSize
        }

        fileprivate var dotRadius: CGFloat {
            compact ? 5 : 6
        }
    }

    private let backgroundLayer = CALayer()
    private let stack = NSStackView()
    private let iconImageView = NSImageView()
    private let dotContainerView = NSView()
    private let dotView = NSView()
    private let nameField = ChipTextField()
    private lazy var clickGestureRecognizer = NSClickGestureRecognizer(
        target: self,
        action: #selector(handleClick)
    )
    private var nameFieldWidthConstraint: Constraint?

    private var config: Config
    private var isHovering = false
    private var isDraggingOver = false
    private var didHandleEditingCompletion = false
    private var helpTextUpdateTask: Task<Void, Never>?

    var isSelected: Bool {
        get { config.isSelected }
        set {
            config.isSelected = newValue
            updateAppearance(animated: true)
        }
    }

    // MARK: - Init

    init(config: Config) {
        self.config = config
        super.init(frame: .zero)
        setup()
        updateContent()
        updateAppearance(animated: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true

        backgroundLayer.masksToBounds = true
        layer?.addSublayer(backgroundLayer)

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = Const.space6
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }

        iconImageView.imageScaling = .scaleProportionallyDown

        dotContainerView.snp.makeConstraints { make in
            make.width.height.equalTo(config.iconContainerSize)
        }
        dotView.wantsLayer = true
        dotContainerView.addSubview(dotView)
        dotView.snp.makeConstraints { make in
            make.width.height.equalTo(config.smallIconPt)
            make.center.equalToSuperview()
        }

        nameField.delegate = self
        nameField.font = .systemFont(
            ofSize: config.labelFontSize,
            weight: .regular
        )
        nameField.isBordered = false
        nameField.drawsBackground = false
        nameField.maximumNumberOfLines = 1
        nameField.lineBreakMode = .byClipping
        nameField.cell?.isScrollable = false
        nameField.cell?.wraps = false
        nameField.cell?.usesSingleLineMode = true
        nameField.setContentHuggingPriority(.required, for: .horizontal)
        nameField.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
        nameField.focusRingMaskView = self
        nameField.containerCornerRadius = config.compact ? Const.btnRadius : Const.radius
        nameField.onFocusChange = { [weak self] focused in
            self?.handleNameFieldFocusChange(focused)
        }

        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [
                    .mouseEnteredAndExited, .activeAlways, .inVisibleRect,
                ],
                owner: self,
                userInfo: nil
            )
        )

        addGestureRecognizer(clickGestureRecognizer)

        registerForDraggedTypes(PasteboardType.supportTypes)
    }

    private var contentInsets: NSEdgeInsets {
        if config.compact {
            let h: CGFloat = config.dotMode ? Const.space4 : Const.space6
            return NSEdgeInsets(
                top: haloInset + Const.space4,
                left: haloInset + h,
                bottom: haloInset + Const.space4,
                right: haloInset + h
            )
        }
        let horizontalInset: CGFloat =
            config.dotMode ? Const.space6 : Const.space10
        return NSEdgeInsets(
            top: haloInset + Const.space6,
            left: haloInset + horizontalInset,
            bottom: haloInset + Const.space6,
            right: haloInset + horizontalInset
        )
    }

    private var displayedName: String {
        if config.isEditing {
            return config.editingName
        }
        return config.chip.name
    }

    private func updateContent() {
        for arrangedSubview in stack.arrangedSubviews {
            stack.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }
        nameFieldWidthConstraint?.deactivate()
        nameFieldWidthConstraint = nil

        stack.snp.remakeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }

        if config.dotMode {
            if config.chip.isSystem {
                let icon: NSImage? = NSImage(
                    systemSymbolName:
                    "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    accessibilityDescription: nil
                )
                iconImageView.image = icon?.withSymbolConfiguration(
                    .init(pointSize: config.smallIconPt, weight: .medium)
                )
                iconImageView.snp.remakeConstraints { make in
                    make.width.height.equalTo(config.iconContainerSize)
                }
                stack.addArrangedSubview(iconImageView)
            } else {
                configureDot(colorIndex: config.chip.colorIndex)
                stack.addArrangedSubview(dotContainerView)
            }
            invalidateIntrinsicContentSize()
            return
        }

        if !config.compact {
            if config.chip.id == -1 {
                let icon: NSImage? = NSImage(
                    systemSymbolName:
                    "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    accessibilityDescription: nil
                )
                iconImageView.image = icon?.withSymbolConfiguration(
                    .init(pointSize: config.iconContainerSize, weight: .regular)
                )
                iconImageView.snp.remakeConstraints { make in
                    make.width.height.equalTo(config.iconContainerSize)
                }
                stack.addArrangedSubview(iconImageView)
            } else {
                let colorIndex =
                    config.isEditing
                        ? config.editingColorIndex : config.chip.colorIndex
                configureDot(colorIndex: colorIndex)
                stack.addArrangedSubview(dotContainerView)
            }
        }

        nameField.stringValue = displayedName
        nameField.isEditable = config.isEditing
        nameField.isSelectable = config.isEditing
        clickGestureRecognizer.isEnabled = !config.isEditing
        stack.addArrangedSubview(nameField)
        nameField.snp.remakeConstraints { make in
            nameFieldWidthConstraint =
                make.width.equalTo(nameFieldDisplayWidth()).constraint
        }

        if config.isEditing {
            didHandleEditingCompletion = false
            Task { @MainActor [weak self] in
                guard let self, config.isEditing else { return }
                window?.makeFirstResponder(nameField)
                nameField.moveCursorToEnd()
            }
        }

        invalidateIntrinsicContentSize()
    }

    private func nameFieldDisplayWidth() -> CGFloat {
        let font = nameField.font ?? .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let text = displayedName.isEmpty ? " " : displayedName
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        return ceil(width)
    }

    private func configureDot(colorIndex: Int) {
        let index = min(max(colorIndex, 0), CategoryChip.palette.count - 1)
        dotView.layer?.cornerRadius = config.dotRadius
        let color = NSColor(CategoryChip.palette[index])
        effectiveAppearance.performAsCurrentDrawingAppearance {
            dotView.layer?.backgroundColor = color.cgColor
        }
    }

    private func updateAppearance(animated: Bool) {
        var resolvedBgCGColor: CGColor = .clear
        var resolvedFgColor: NSColor = .labelColor

        effectiveAppearance.performAsCurrentDrawingAppearance {
            resolvedBgCGColor = resolvedBackgroundColor().cgColor
            resolvedFgColor = resolvedForegroundColor()
        }

        nameField.textColor = resolvedFgColor
        iconImageView.contentTintColor = resolvedFgColor

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.allowsImplicitAnimation = true
                self.backgroundLayer.backgroundColor = resolvedBgCGColor
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            backgroundLayer.backgroundColor = resolvedBgCGColor
            CATransaction.commit()
        }
    }

    private func resolvedBackgroundColor() -> NSColor {
        let isDark =
            effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        if config.dotMode {
            if isDraggingOver {
                return isDark
                    ? .quaternaryLabelColor
                    : .labelColor.withAlphaComponent(0.06)
            }
            return isHovering
                ? isDark
                ? .quaternaryLabelColor
                : .labelColor.withAlphaComponent(0.06)
                : .clear
        }

        if config.compact {
            let chipColor = compactChipColor()
            if config.isSelected || config.isEditing {
                return chipColor
            }
            if isHovering || isDraggingOver {
                return isDark
                    ? .quaternaryLabelColor.withAlphaComponent(0.06)
                    : .labelColor.withAlphaComponent(0.06)
            }
            return .clear
        }

        if config.isSelected || config.isEditing {
            return isDark
                ? .quaternaryLabelColor : .labelColor.withAlphaComponent(0.1)
        }

        if isHovering || isDraggingOver {
            return isDark
                ? .quaternaryLabelColor.withAlphaComponent(0.06)
                : .labelColor.withAlphaComponent(0.06)
        }

        return .clear
    }

    private func compactChipColor() -> NSColor {
        config.chip.id == -1
            ? .controlAccentColor
            : CategoryChip.nsColor(at: config.chip.colorIndex, alpha: 1.0)
    }

    private func resolvedForegroundColor() -> NSColor {
        if config.compact, config.isSelected || config.isEditing {
            return .white
        }
        return .labelColor
    }

    override var intrinsicContentSize: NSSize {
        let fitting = stack.fittingSize
        return NSSize(
            width: fitting.width + contentInsets.left + contentInsets.right,
            height: fitting.height + contentInsets.top + contentInsets.bottom
        )
    }

    override func layout() {
        super.layout()

        let pillFrame = bounds.insetBy(dx: haloInset, dy: haloInset)
        backgroundLayer.frame = pillFrame
        backgroundLayer.cornerRadius =
            config.compact ? Const.btnRadius : Const.radius
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance(animated: false)

        let colorIndex =
            config.isEditing
                ? config.editingColorIndex : config.chip.colorIndex
        if !config.chip.isSystem || !config.dotMode {
            configureDot(colorIndex: colorIndex)
        }
    }

    // MARK: - Mouse

    override func mouseEntered(with _: NSEvent) {
        isHovering = true
        updateAppearance(animated: true)
        updateHelpText()
    }

    override func mouseExited(with _: NSEvent) {
        isHovering = false
        updateAppearance(animated: true)
        helpTextUpdateTask?.cancel()
        helpTextUpdateTask = nil
        toolTip = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        guard !config.dotMode, !config.chip.isSystem, !config.isEditing else {
            super.rightMouseDown(with: event)
            return
        }

        let menu = NSMenu()

        let editItem = NSMenuItem(
            title: String(localized: .rename),
            action: #selector(handleEditAction),
            keyEquivalent: ""
        )
        editItem.target = self
        editItem.image = NSImage(
            systemSymbolName: "pencil",
            accessibilityDescription: nil
        )
        menu.addItem(editItem)

        let deleteItem = NSMenuItem(
            title: String(localized: .delete),
            action: #selector(handleDeleteAction),
            keyEquivalent: ""
        )
        deleteItem.target = self
        deleteItem.image = NSImage(
            systemSymbolName: "trash",
            accessibilityDescription: nil
        )
        menu.addItem(deleteItem)

        menu.addItem(.separator())

        let colorItem = NSMenuItem()
        colorItem.view = ChipColorPaletteMenuView(
            currentColorIndex: config.chip.colorIndex,
            onColorChange: { [weak self, weak menu] index in
                menu?.cancelTracking()
                self?.config.onColorChange?(index)
            }
        )
        menu.addItem(colorItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func handleClick() {
        guard !config.isEditing else { return }
        config.action()
    }

    @objc private func handleEditAction() {
        config.onEdit?()
    }

    @objc private func handleDeleteAction() {
        config.onDelete?()
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === nameField else {
            return
        }
        updateNameFieldWidth()

        if let editor = nameField.currentEditor() as? NSTextView {
            let range = editor.markedRange()
            let isMarked = range.location != NSNotFound && range.length > 0
            if !isMarked {
                config.onEditingNameChange?(field.stringValue)
            }
        } else {
            config.onEditingNameChange?(field.stringValue)
        }
    }

    // MARK: - Focus & IME Tracking

    private func handleNameFieldFocusChange(_ focused: Bool) {
        config.onEditingFocusChange?(focused)
    }

    private func updateNameFieldWidth() {
        let displayText: String =
            if let editor = nameField.currentEditor() as? NSTextView,
            !editor.string.isEmpty {
                editor.string
            } else {
                nameField.stringValue
            }
        let font = nameField.font ?? .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let text = displayText.isEmpty ? " " : displayText
        let width = ceil(
            (text as NSString).size(withAttributes: [.font: font]).width
        )
        nameFieldWidthConstraint?.update(offset: width)
        invalidateIntrinsicContentSize()
        needsLayout = true
        onWidthChanged?()
    }

    var onWidthChanged: (() -> Void)?

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField,
              field === nameField,
              config.isEditing,
              !didHandleEditingCompletion
        else { return }

        didHandleEditingCompletion = true
        config.onEditingSubmit?()
    }

    func control(
        _: NSControl,
        textView _: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        switch commandSelector {
        case #selector(insertNewline(_:)), #selector(insertTab(_:)):
            didHandleEditingCompletion = true
            config.onEditingSubmit?()
            return true
        case #selector(cancelOperation(_:)):
            didHandleEditingCompletion = true
            config.onEditingCancel?()
            return true
        default:
            return false
        }
    }

    // MARK: - Drag & Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !config.isEditing else {
            return []
        }

        let pasteboard = sender.draggingPasteboard

        guard pasteboard.availableType(from: [.pasteboardModel]) != nil else {
            return []
        }

        isDraggingOver = true
        updateAppearance(animated: true)

        return [.copy, .move]
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !config.isEditing else {
            return []
        }

        let pasteboard = sender.draggingPasteboard
        guard pasteboard.availableType(from: [.pasteboardModel]) != nil else {
            return []
        }

        return [.copy, .move]
    }

    override func draggingExited(_: NSDraggingInfo?) {
        isDraggingOver = false
        updateAppearance(animated: true)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDraggingOver = false
        updateAppearance(animated: true)

        guard !config.isEditing else {
            return false
        }

        let pasteboard = sender.draggingPasteboard

        guard let data = pasteboard.data(forType: .pasteboardModel) else {
            return false
        }

        guard
            let model = try? JSONDecoder()
            .decode(PasteboardModel.self, from: data)
        else {
            return false
        }

        return config.onDrop?(model) ?? false
    }

    // MARK: - Help Text

    private func updateHelpText() {
        helpTextUpdateTask?.cancel()

        helpTextUpdateTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let count: Int =
                if config.chip.id == -1 {
                    PasteDataStore.main.totalCount
                } else {
                    await PasteDataStore.main.getCountByGroup(
                        groupId: config.chip.id
                    )
                }

            guard !Task.isCancelled else { return }

            var shortcutText = ""
            if let prevInfo = HotKeyManager.shared.getHotKey(
                key: "previous_tab"
            ),
                let nextInfo = HotKeyManager.shared.getHotKey(key: "next_tab"),
                prevInfo.isEnabled,
                nextInfo.isEnabled
            {
                let prevDisplay = prevInfo.shortcut.displayString
                let nextDisplay = nextInfo.shortcut.displayString
                shortcutText = String(
                    localized: .chipTabs(prevDisplay, nextDisplay)
                )
            }

            let helpText = String(localized: .chipHelp(count, shortcutText))

            guard !Task.isCancelled else { return }
            toolTip = helpText
        }
    }
}

private final class ChipTextField: NSTextField {
    weak var focusRingMaskView: NSView?
    var containerCornerRadius: CGFloat = Const.radius
    var focusRingInset: CGFloat = 4
    var onFocusChange: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        (cell as? NSTextFieldCell)?.setWantsNotificationForMarkedText(true)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override var focusRingType: NSFocusRingType {
        get { .exterior }
        set {}
    }

    override var focusRingMaskBounds: NSRect {
        guard let focusRingMaskView else { return bounds }
        return focusRingMaskView.convert(
            focusRingMaskView.bounds.insetBy(
                dx: focusRingInset,
                dy: focusRingInset
            ),
            to: self
        )
    }

    override func drawFocusRingMask() {
        let maskRect = focusRingMaskBounds
        NSBezierPath(
            roundedRect: maskRect,
            xRadius: containerCornerRadius,
            yRadius: containerCornerRadius
        ).fill()
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            noteFocusRingMaskChanged()
            onFocusChange?(true)
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            onFocusChange?(false)
        }
        return result
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if isEditable {
            window?.makeFirstResponder(self)
        }
    }

    func moveCursorToEnd() {
        guard let editor = currentEditor() else { return }
        let end = editor.string.endIndex
        editor.selectedRange = NSRange(end..., in: editor.string)
    }
}

private final class ChipColorPaletteMenuView: NSView {
    private let stack = NSStackView()

    init(currentColorIndex: Int, onColorChange: @escaping (Int) -> Void) {
        super.init(frame: .zero)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12

        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        for (index, color) in CategoryChip.palette.enumerated() {
            let circle = ChipColorCircleView(
                color: NSColor(color),
                isSelected: index == currentColorIndex,
                onTap: { onColorChange(index) }
            )
            stack.addArrangedSubview(circle)
            circle.snp.makeConstraints { make in
                make.width.height.equalTo(14)
            }
        }

        layoutSubtreeIfNeeded()
        frame.size = fittingSize
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}

private final class ChipColorCircleView: NSView {
    private let color: NSColor
    private let isSelected: Bool
    private let onTap: () -> Void
    private var isHovering = false

    init(color: NSColor, isSelected: Bool, onTap: @escaping () -> Void) {
        self.color = color
        self.isSelected = isSelected
        self.onTap = onTap
        super.init(frame: .zero)
        wantsLayer = true

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)

        let click = NSClickGestureRecognizer(
            target: self,
            action: #selector(handleTap)
        )
        addGestureRecognizer(click)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func mouseEntered(with _: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with _: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(ovalIn: rect)
        color.setFill()
        path.fill()

        if isSelected || isHovering {
            NSColor.white.withAlphaComponent(0.8).setStroke()
            path.lineWidth = isSelected ? 2 : 1.5
            path.stroke()
        }
    }

    @objc private func handleTap() {
        onTap()
    }
}
