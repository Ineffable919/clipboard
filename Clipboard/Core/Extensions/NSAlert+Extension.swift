//
//  NSAlert+Extension.swift
//  Clipboard
//

import AppKit

extension NSAlert {
    /// Shows a warning-style confirm/cancel alert and returns true if the user confirmed.
    /// Suppresses window resign-key events while the alert is running.
    static func runConfirm(title: String, message: String) -> Bool {
        AppEnvironment.shared.suppressResignKey = true
        defer { AppEnvironment.shared.suppressResignKey = false }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: .commonConfirm))
        alert.addButton(withTitle: String(localized: .commonCancel))
        return alert.runModal() == .alertFirstButtonReturn
    }
}
