import Combine
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    var actions: ClipboardActionService {
        ClipboardActionService()
    }

    @Published var focusView: FocusField = .history
    @Published var isShowDel: Bool = false
    @Published var quickPasteResetTrigger: Bool = false
    var draggingItemId: Int64?
    var preApp: NSRunningApplication?

    init() {}

    func resetQuickPasteState() {
        quickPasteResetTrigger.toggle()
    }
}
