import Combine
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    var actions: ClipboardActionService {
        ClipboardActionService()
    }

    @Published var focusView: FocusField = .history

    // UI 状态
    @Published var isShowDel: Bool = false
    var draggingItemId: Int64?

    // 快速粘贴状态重置
    @Published var quickPasteResetTrigger: Bool = false

    init() {}

    func resetQuickPasteState() {
        quickPasteResetTrigger.toggle()
    }
}
