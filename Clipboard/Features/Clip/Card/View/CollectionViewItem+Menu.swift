import AppKit

// MARK: - Context Menu

extension CollectionViewItem: ClipItemMenuActionable {
    private var pasteMenuTitle: String {
        if let appName = delegate?.preApp?.localizedName, PasteUserDefaults.pasteDirect {
            String(localized: .pasteToApp(appName))
        } else {
            String(localized: .paste)
        }
    }

    func handleClipPaste() {
        guard let model = item else { return }
        delegate?.paste(model)
    }

    func handleClipPastePlain() {
        guard let model = item else { return }
        delegate?.pastePlain(model)
    }

    func handleClipCopy() {
        guard let model = item else { return }
        delegate?.copy(model)
    }

    func handleClipEdit() {
        guard let model = item else { return }
        delegate?.edit(model)
    }

    func handleClipDelete() {
        guard let model = item, let indexPath = collectionView?.indexPath(for: self) else { return }
        delegate?.delete(model, indexPath: indexPath)
    }

    func handleClipAssignToChip(_ sender: NSMenuItem) {
        guard let model = item, model.group != sender.tag else { return }
        delegate?.assignToChip(model, chipId: sender.tag)
    }

    func handleClipCreateChip() {
        guard let model = item else { return }
        delegate?.createChip(pinning: model)
    }

    func handleClipUnpin() {
        guard let model = item else { return }
        delegate?.assignToChip(model, chipId: -1)
    }

    func handleClipPreview() {
        guard let model = item else { return }
        delegate?.preview(model)
    }

    func handleClipRevealInFinder() {
        guard let paths = item?.cachedFilePaths, !paths.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
    }

    func handleClipOpenInBrowser() {
        guard let model = item, let url = URL(string: model.plainText) else { return }
        NSWorkspace.shared.open(url)
    }

    func handleClipOpenWithDefaultApp() {
        guard let path = item?.cachedFilePaths?.first else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}

// MARK: - NSMenuDelegate

extension CollectionViewItem: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let model = item else { return }
        delegate?.itemDidRequestSelect(self)
        for item in buildClipItemMenu(for: model, pasteTitle: pasteMenuTitle).items {
            menu.addItem(item)
        }
    }
}
