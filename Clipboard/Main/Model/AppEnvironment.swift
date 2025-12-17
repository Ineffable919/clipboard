import Combine
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {

    var actions: ClipboardActionService {
        ClipboardActionService()
    }

    @Published var focusView: FocusField = .history {
        didSet {
            EventDispatcher.shared.bypassAllEvents = focusView != .history
        }
    }

    // UI 状态
    @Published var isShowDel: Bool = false
    @Published var draggingItemId: Int64?

    init() {}
}
