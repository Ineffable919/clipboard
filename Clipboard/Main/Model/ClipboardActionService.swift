import Foundation

struct ClipboardActionService {
    private let pasteBoard = PasteBoard.main
    private let userDefaults = PasteUserDefaults.self
    private let dataStore = PasteDataStore.main

    func paste(
        _ item: PasteboardModel,
        isAttribute: Bool = true
    ) {
        pasteBoard.pasteData(item, isAttribute)
        guard userDefaults.pasteDirect else {
            ClipMainWindowController.shared.toggleWindow()
            return
        }
        ClipMainWindowController.shared.toggleWindow {
            KeyboardShortcuts.postCmdVEvent()
        }
    }

    func copy(_ item: PasteboardModel, isAttribute: Bool = true) {
        pasteBoard.pasteData(item, isAttribute)
    }

    func delete(_ item: PasteboardModel) {
        if item.group != -1 {
            do {
                try dataStore.updateItemGroup(
                    itemId: item.id!,
                    groupId: -1
                )
            } catch {
                log.error("更新卡片 group 失败: \(error)")
            }
            return
        }
        dataStore.deleteItems(item)
    }
}
