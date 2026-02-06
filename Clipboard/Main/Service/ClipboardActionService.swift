import AppKit
import Foundation

struct ClipboardActionService {
    private let pasteBoard = PasteBoard.main
    private let userDefaults = PasteUserDefaults.self
    private let dataStore = PasteDataStore.main

    func paste(
        _ item: PasteboardModel,
        isAttribute: Bool = true
    ) {
        let hasPermission = AXIsProcessTrusted()

        if !hasPermission {
            log.debug(
                "Accessibility permission not granted, cannot send keyboard events"
            )
            DispatchQueue.main.async {
                requestAccessibilityPermission(
                    item: item,
                    isAttribute: isAttribute
                )
            }
            return
        }

        pasteBoard.pasteData(item, isAttribute)
        guard userDefaults.pasteDirect else {
            WindowManager.shared.toggleWindow()
            return
        }
        WindowManager.shared.toggleWindow {
            KeyboardShortcuts.postCmdVEvent()
        }
    }

    func copy(_ item: PasteboardModel, isAttribute: Bool = true) {
        pasteBoard.pasteData(item, isAttribute)
    }

    func delete(_ item: PasteboardModel) {
        if item.group != -1, let id = item.id {
            do {
                try dataStore.updateItemGroup(
                    itemId: id,
                    groupId: -1
                )
            } catch {
                log.error("更新卡片 group 失败: \(error)")
            }
            return
        }
        dataStore.deleteItems(item)
    }

    private func requestAccessibilityPermission(
        item: PasteboardModel,
        isAttribute: Bool = true
    ) {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = """
        Clipboard 需要获取辅助功能权限
        才能直接粘贴到其它应用
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "设置")
        alert.addButton(withTitle: "稍后设置，复制到剪贴板")

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
            pasteBoard.pasteData(item, isAttribute)
        default:
            break
        }
    }
}
