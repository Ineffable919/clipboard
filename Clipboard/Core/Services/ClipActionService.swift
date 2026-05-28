import AppKit
import Foundation

@MainActor
final class ClipActionService {
    static let shared = ClipActionService()

    private let pasteBoard = PasteBoard.main
    private let userDefaults = PasteUserDefaults.self
    private let dataStore = PasteDataStore.main

    private init() {}

    func paste(
        _ item: PasteboardModel,
        isAttribute: Bool = true,
        checkPermissions: Bool = false,
        showTip: Bool = false
    ) {
        guard userDefaults.pasteDirect, checkPermissions else {
            pasteBoard.pasteMultipleData(
                [item],
                isAttribute: isAttribute,
                showTip: showTip
            )
            WindowManager.shared.toggleWindow()
            return
        }
        let hasPermission = AXIsProcessTrusted()

        if !hasPermission {
            log.debug(
                "Accessibility permission not granted, cannot send keyboard events"
            )
            WindowManager.shared.toggleWindow {
                Task { @MainActor in
                    self.requestAccessibilityPermission(
                        items: [item],
                        isAttribute: isAttribute,
                        showTip: true
                    )
                }
            }
            return
        }
        pasteBoard.pasteMultipleData(
            [item],
            isAttribute: isAttribute
        )
        WindowManager.shared.toggleWindow {
            KeyboardShortcuts.postCmdVEvent()
        }
    }

    func copy(
        _ item: PasteboardModel,
        isAttribute: Bool = true,
        showTip: Bool = false
    ) {
        pasteBoard.pasteMultipleData(
            [item],
            isAttribute: isAttribute,
            showTip: showTip,
            copy: true
        )
        WindowManager.shared.toggleWindow()
    }

    func copyMultiple(_ items: [PasteboardModel], isAttribute: Bool = true) {
        pasteBoard.pasteMultipleData(
            items,
            isAttribute: isAttribute,
            showTip: true,
            copy: true
        )
    }

    func pasteMultiple(
        _ items: [PasteboardModel],
        isAttribute: Bool = true,
        checkPermissions: Bool = false,
        showTip: Bool = false
    ) {
        guard !items.isEmpty else { return }

        if items.count == 1 {
            paste(
                items[0],
                isAttribute: isAttribute,
                checkPermissions: checkPermissions,
                showTip: showTip
            )
            return
        }

        guard userDefaults.pasteDirect, checkPermissions else {
            pasteBoard.pasteMultipleData(items, isAttribute: isAttribute)
            WindowManager.shared.toggleWindow()
            return
        }

        let hasPermission = AXIsProcessTrusted()
        guard hasPermission else {
            log.debug(
                "Accessibility permission not granted, cannot send keyboard events"
            )
            WindowManager.shared.toggleWindow {
                Task { @MainActor in
                    self.requestAccessibilityPermission(
                        items: items,
                        isAttribute: isAttribute,
                        showTip: true
                    )
                }
            }
            return
        }

        pasteBoard.pasteMultipleData(items, isAttribute: isAttribute)
        WindowManager.shared.toggleWindow {
            KeyboardShortcuts.postCmdVEvent()
        }
    }

    private func requestAccessibilityPermission(
        items: [PasteboardModel],
        isAttribute: Bool = true,
        showTip: Bool = false
    ) {
        let alert = NSAlert()
        alert.messageText = String(localized: .accessTitle)
        alert.informativeText = String(localized: .accessMessage)
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: .openSettings))
        alert.addButton(withTitle: String(localized: .copyLater))

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            if let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            ) {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            pasteBoard.pasteMultipleData(
                items,
                isAttribute: isAttribute,
                showTip: showTip
            )
        default:
            break
        }
    }
}
