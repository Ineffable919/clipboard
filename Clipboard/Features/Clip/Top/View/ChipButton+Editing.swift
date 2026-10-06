import AppKit
import SnapKit

extension ChipButton {
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

    func handleNameFieldFocusChange(_ focused: Bool) {
        config.onEditingFocusChange?(focused)
    }

    func updateNameFieldWidth() {
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

    // MARK: - Help Text

    func updateHelpText() {
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
                nextInfo.isEnabled {
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

extension ChipButton {
    func update(config newConfig: Config) {
        let rebuild = config.chip != newConfig.chip
            || config.dotMode != newConfig.dotMode
            || config.compact != newConfig.compact
            || config.isEditing != newConfig.isEditing
        config = newConfig
        if rebuild {
            updateContent()
        }
        updateAppearance(animated: false)
    }
}

extension ChipButton {
    var modeIconOrigin: NSPoint { stack.convert(.zero, to: self) }
    var modeBackground: CALayer { backgroundLayer }
    var modeLabel: CALayer? {
        nameField.wantsLayer = true
        return nameField.layer
    }
}
