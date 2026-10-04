//
//  FloatingCardRowView+Menu.swift
//  Clipboard
//

import AppKit

// MARK: - ClipItemMenuActionable

extension FloatingCardRowView: ClipItemMenuActionable {
    func handleClipPaste() {
        onPaste?()
    }

    func handleClipPastePlain() {
        onPastePlainText?()
    }

    func handleClipCopy() {
        onCopy?()
    }

    func handleClipEdit() {
        onEdit?()
    }

    func handleClipDelete() {
        onDelete?()
    }

    func handleClipPreview() {
        onTogglePreview?()
    }

    func handleClipAssignToChip(_ sender: NSMenuItem) {
        guard let model = currentModel, model.group != sender.tag else { return }
        onAssignToChip?(sender.tag)
    }

    func handleClipCreateChip() {
        guard let model = currentModel else { return }
        onCreateChip?(model)
    }

    func handleClipUnpin() {
        onAssignToChip?(-1)
    }

    func handleClipRevealInFinder() {
        guard let paths = currentModel?.cachedFilePaths, !paths.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
    }

    func handleClipOpenInBrowser() {
        guard let model = currentModel, let url = URL(string: model.plainText) else { return }
        NSWorkspace.shared.open(url)
    }

    func handleClipOpenWithDefaultApp() {
        guard let path = currentModel?.cachedFilePaths?.first else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}

// MARK: - NSMenuDelegate

extension FloatingCardRowView: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let model = currentModel else { return }
        let pasteTitle = if let appName = AppEnvironment.shared.previousApp?.localizedName,
                            PasteUserDefaults.pasteDirect {
            String(localized: .pasteToApp(appName))
        } else {
            String(localized: .paste)
        }
        for item in buildClipItemMenu(for: model, pasteTitle: pasteTitle).items {
            menu.addItem(item)
        }
    }
}
