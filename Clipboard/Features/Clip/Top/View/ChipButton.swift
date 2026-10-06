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
    let haloInset: CGFloat = 4

    struct Config {
        let chip: CategoryChip
        var isSelected: Bool
        var dotMode: Bool = false
        var compact: Bool = false
        var isEditing: Bool = false
        var editingName: String = ""
        var editingColorIndex: Int = 0
        var allowsColorCycling: Bool = false
        var action: () -> Void
        var onEdit: (() -> Void)?
        var onDelete: (() -> Void)?
        var onColorChange: ((Int) -> Void)?
        var onEditingNameChange: ((String) -> Void)?
        var onEditingSubmit: (() -> Void)?
        var onEditingCancel: (() -> Void)?
        var onEditingFocusChange: ((Bool) -> Void)?
        var onDrop: ((PasteboardModel) -> Bool)?

        var iconContainerSize: CGFloat {
            compact ? 14 : 16
        }

        var smallIconPt: CGFloat {
            compact ? 10 : 12
        }

        var labelFontSize: CGFloat {
            compact ? NSFont.smallSystemFontSize : NSFont.systemFontSize
        }

        var dotRadius: CGFloat {
            compact ? 5 : 6
        }
    }

    let backgroundLayer = CALayer()
    let stack = NSStackView()
    let iconImageView = NSImageView()
    let dotContainerView = NSView()
    let dotView = NSView()
    let nameField = ChipTextField()
    lazy var clickGestureRecognizer = NSClickGestureRecognizer(
        target: self,
        action: #selector(handleClick)
    )
    lazy var dotClickGestureRecognizer = NSClickGestureRecognizer(
        target: self,
        action: #selector(handleDotClick)
    )
    var nameFieldWidthConstraint: Constraint?

    var config: Config
    var isHovering = false
    var isDraggingOver = false
    var didHandleEditingCompletion = false
    var helpTextUpdateTask: Task<Void, Never>?

    var isSelected: Bool {
        get { config.isSelected }
        set {
            config.isSelected = newValue
            updateAppearance(animated: true)
        }
    }

    var onWidthChanged: (() -> Void)?

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

        menu.addItem(makeMenuItem(
            title: String(localized: .rename), action: #selector(handleEditAction), symbolName: "pencil"
        ))
        menu.addItem(makeMenuItem(
            title: String(localized: .delete), action: #selector(handleDeleteAction), symbolName: "trash"
        ))

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

    func makeMenuItem(title: String, action: Selector, symbolName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        return item
    }

    @objc func handleClick() {
        guard !config.isEditing else { return }
        config.action()
    }

    @objc func handleDotClick() {
        guard canCycleColor else { return }
        let nextIndex =
            (config.editingColorIndex + 1) % CategoryChip.palette.count
        updateDotColor(nextIndex)
        config.onColorChange?(nextIndex)
    }

    func updateDotColor(_ colorIndex: Int) {
        guard config.isEditing else { return }
        config.editingColorIndex = min(
            max(colorIndex, 0),
            CategoryChip.palette.count - 1
        )
        configureDot(colorIndex: config.editingColorIndex)
    }

    @objc func handleEditAction() {
        config.onEdit?()
    }

    @objc func handleDeleteAction() {
        config.onDelete?()
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

}
