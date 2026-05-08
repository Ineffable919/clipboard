//
//  ClipItemContextMenu.swift
//  Clipboard
//
//  剪贴条目右键菜单
//

import AppKit

// MARK: - Actionable Protocol

@objc protocol ClipItemMenuActionable: AnyObject {
    func handleClipPaste()
    func handleClipPastePlain()
    func handleClipCopy()
    func handleClipEdit()
    func handleClipDelete()
    func handleClipAssignToChip(_ sender: NSMenuItem)
    func handleClipUnpin()
    func handleClipPreview()
}

// MARK: - Default Menu Builder

extension ClipItemMenuActionable where Self: NSObject {
    func buildClipItemMenu(for model: PasteboardModel, pasteTitle: String) -> NSMenu {
        let menu = NSMenu()

        menu.addItem(makeMenuItem(
            title: pasteTitle,
            symbol: "doc.on.clipboard",
            action: #selector(ClipItemMenuActionable.handleClipPaste),
            keyEquivalent: "\r"
        ))
        menu.addItem(makeMenuItem(
            title: String(localized: .pastePlain),
            symbol: "text.alignleft",
            action: #selector(ClipItemMenuActionable.handleClipPastePlain),
            keyEquivalent: "\r",
            modifiers: .shift
        ))
        menu.addItem(makeMenuItem(
            title: String(localized: .copy),
            symbol: "doc.on.doc",
            action: #selector(ClipItemMenuActionable.handleClipCopy),
            keyEquivalent: "c",
            modifiers: .command
        ))
        menu.addItem(.separator())

        if model.pasteboardType.isText() {
            menu.addItem(makeMenuItem(
                title: String(localized: .edit),
                symbol: "pencil",
                action: #selector(ClipItemMenuActionable.handleClipEdit),
                keyEquivalent: "e",
                modifiers: .command
            ))
        }

        menu.addItem(makeMenuItem(
            title: String(localized: .delete),
            symbol: "trash",
            action: #selector(ClipItemMenuActionable.handleClipDelete),
            keyEquivalent: "\u{08}"
        ))
        menu.addItem(.separator())
        menu.addItem(makePinMenuItem(for: model))
        menu.addItem(.separator())
        menu.addItem(makeMenuItem(
            title: String(localized: .preview),
            symbol: "eye",
            action: #selector(ClipItemMenuActionable.handleClipPreview),
            keyEquivalent: " "
        ))

        return menu
    }

    // MARK: - Item Factories

    private func makeMenuItem(
        title: String,
        symbol: String?,
        action: Selector,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        return item
    }

    private func makePinMenuItem(for model: PasteboardModel) -> NSMenuItem {
        let parent = NSMenuItem(title: String(localized: .pin), action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: "pin", accessibilityDescription: nil)

        let submenu = NSMenu()
        let userChips = CategoryChipStore.shared.chips.filter { !$0.isSystem }
        for chip in userChips {
            let chipItem = NSMenuItem(
                title: chip.name,
                action: #selector(ClipItemMenuActionable.handleClipAssignToChip(_:)),
                keyEquivalent: ""
            )
            chipItem.target = self
            chipItem.tag = chip.id
            chipItem.state = model.group == chip.id ? .on : .off
            chipItem.image = clipChipDotImage(colorIndex: chip.colorIndex)
            submenu.addItem(chipItem)
        }

        if model.group != -1 {
            submenu.addItem(.separator())
            let unpinItem = NSMenuItem(
                title: String(localized: .unpin),
                action: #selector(ClipItemMenuActionable.handleClipUnpin),
                keyEquivalent: ""
            )
            unpinItem.target = self
            submenu.addItem(unpinItem)
        }

        parent.submenu = submenu
        return parent
    }
}

// MARK: - Shared Helpers

func clipChipDotImage(colorIndex: Int) -> NSImage {
    let size = NSSize(width: 12, height: 12)
    let image = NSImage(size: size, flipped: false) { rect in
        let color = CategoryChip.paletteNSColors[
            min(max(colorIndex, 0), CategoryChip.paletteNSColors.count - 1)
        ]
        color.setFill()
        NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
        return true
    }
    image.isTemplate = false
    return image
}
