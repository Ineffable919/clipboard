import AppKit

// MARK: - 快捷键模型

struct KeyboardShortcut: Codable, Equatable, Hashable {
    var modifiersRawValue: UInt = 0
    var keyCode: UInt16 = 0
    var displayKey: String = ""

    var modifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: modifiersRawValue) }
        set { modifiersRawValue = newValue.rawValue }
    }

    var isEmpty: Bool {
        displayKey.isEmpty && modifiersRawValue == 0
    }

    var displayString: String {
        guard !isEmpty else { return "" }
        return modifiers.symbols + displayKey
    }

    static var empty = KeyboardShortcut()
}

extension NSEvent.ModifierFlags {
    var symbols: String {
        var shortcut = ""
        if contains(.command) {
            shortcut += "⌘"
        }
        if contains(.option) {
            shortcut += "⌥"
        }
        if contains(.control) {
            shortcut += "⌃"
        }
        if contains(.shift) {
            shortcut += "⇧"
        }
        return shortcut
    }
}

// MARK: - 存储快捷键模型

struct HotKeyInfo: Codable, Identifiable, Equatable {
    let key: String
    let shortcut: KeyboardShortcut
    let isEnabled: Bool
    let isGlobal: Bool

    var id: String {
        key
    }

    init(
        key: String,
        shortcut: KeyboardShortcut,
        isEnabled: Bool = true,
        isGlobal: Bool = true
    ) {
        self.key = key
        self.shortcut = shortcut
        self.isEnabled = isEnabled
        self.isGlobal = isGlobal
    }

    var displayText: String {
        shortcut.displayString
    }
}
