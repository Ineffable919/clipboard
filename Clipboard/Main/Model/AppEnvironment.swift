import SwiftUI

@Observable
final class AppEnvironment {
    let searchVM = SearchViewModel()
    let chipVM = ChipBarViewModel()

    var actions: ClipboardActionService {
        ClipboardActionService()
    }

    var focusView: FocusField = .history {
        didSet {
            EventDispatcher.shared.bypassAllEvents =
                (focusView == .popover || focusView == .search)
        }
    }

    // UI 状态
    var isShowDel: Bool = false
    var draggingItemId: Int64?

    init() {}
}
