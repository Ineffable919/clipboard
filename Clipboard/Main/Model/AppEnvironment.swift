import SwiftUI

@Observable
final class AppEnvironment {

    var actions: ClipboardActionService {
        ClipboardActionService()
    }

    var focusView: FocusField = .history {
        didSet {
            EventDispatcher.shared.bypassAllEvents = focusView != .history
        }
    }

    // UI 状态
    var isShowDel: Bool = false
    var draggingItemId: Int64?

    init() {}
}
