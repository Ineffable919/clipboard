import AppKit
import Foundation

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    // MARK: - Focus

    var focusRegion: FocusRegion = .collection

    // MARK: - Selection

    var selectIndexPath = IndexPath(item: 0, section: 0)

    // MARK: - App Switching

    var previousApp: NSRunningApplication?

    // MARK: - UI State

    var suppressResignKey = false
    var quickPasteResetTrigger = false

    private init() {}

    // MARK: - Helpers

    func resetQuickPasteState() {
        quickPasteResetTrigger.toggle()
    }
}
