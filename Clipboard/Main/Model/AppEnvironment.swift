import SwiftUI

@MainActor
@Observable
final class AppEnvironment {
    var actions: ClipboardActionService {
        ClipboardActionService()
    }

    var focusView: FocusField = .history
    var isShowDel: Bool = false
    var quickPasteResetTrigger: Bool = false
    @ObservationIgnored var draggingItemId: Int64?
    @ObservationIgnored var preApp: NSRunningApplication?

    init() {}

    func resetQuickPasteState() {
        quickPasteResetTrigger.toggle()
    }
}
