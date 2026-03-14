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
        checkPermissions: Bool = false
    ) {
        guard userDefaults.pasteDirect, checkPermissions else {
            pasteBoard.pasteMultipleData([item], isAttribute)
            WindowManager.shared.toggleWindow()
            return
        }
        let hasPermission = AXIsProcessTrusted()

        if !hasPermission {
            log.debug(
                "Accessibility permission not granted, cannot send keyboard events"
            )
            Task { @MainActor in
                requestAccessibilityPermission(
                    item: item,
                    isAttribute: isAttribute
                )
            }
            return
        }
        pasteBoard.pasteMultipleData([item], isAttribute)
        WindowManager.shared.toggleWindow {
            KeyboardShortcuts.postCmdVEvent()
        }
    }

    func copy(_ item: PasteboardModel, isAttribute: Bool = true) {
        pasteBoard.pasteMultipleData([item], isAttribute)
    }

    /// 将多个项目合并写入剪贴板
    func copyMultiple(_ items: [PasteboardModel], isAttribute: Bool = true) {
        pasteBoard.pasteMultipleData(items, isAttribute)
    }

    /// 将多个项目合并写入剪贴板并粘贴
    func pasteMultiple(
        _ items: [PasteboardModel],
        isAttribute: Bool = true,
        checkPermissions: Bool = false
    ) {
        guard !items.isEmpty else { return }

        if items.count == 1 {
            paste(
                items[0],
                isAttribute: isAttribute,
                checkPermissions: checkPermissions
            )
            return
        }

        guard userDefaults.pasteDirect, checkPermissions else {
            pasteBoard.pasteMultipleData(items, isAttribute)
            WindowManager.shared.toggleWindow()
            return
        }

        let hasPermission = AXIsProcessTrusted()
        guard hasPermission else {
            log.debug(
                "Accessibility permission not granted, cannot send keyboard events"
            )
            pasteBoard.pasteMultipleData(items, isAttribute)
            WindowManager.shared.toggleWindow()
            return
        }

        pasteBoard.pasteMultipleData(items, isAttribute)
        WindowManager.shared.toggleWindow {
            KeyboardShortcuts.postCmdVEvent()
        }
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
            pasteBoard.pasteMultipleData([item], isAttribute)
        default:
            break
        }
    }
}
