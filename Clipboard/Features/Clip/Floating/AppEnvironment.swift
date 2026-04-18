import AppKit
import Foundation

@MainActor
final class AppEnvironment {
    // MARK: - Singleton

    static let shared = AppEnvironment()

    // MARK: - Focus

    /// 当前键盘焦点所在区域
    var focusRegion: FocusRegion = .collection

    // MARK: - Selection

    /// 当前选中的 CollectionView 索引
    var selectIndexPath = IndexPath(item: 0, section: 0)

    // MARK: - App Switching

    /// 触发粘贴前的前台 App，粘贴后用于切回
    var previousApp: NSRunningApplication?

    // MARK: - UI State

    var suppressResignKey = false
    var quickPasteResetTrigger: Bool = false
    var draggingItemId: Int64?

    private init() {}

    // MARK: - Helpers

    func resetQuickPasteState() {
        quickPasteResetTrigger.toggle()
    }

    /// 当前是否处于文字输入模式（搜索框或 chip 编辑中）
    func isInInputMode() -> Bool {
        focusRegion == .search || focusRegion == .chipEditing
    }
}
