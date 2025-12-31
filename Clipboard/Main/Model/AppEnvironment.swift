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

    init() {}
}
