import AppKit

nonisolated final class JSONFoldAccessibilityElement: NSAccessibilityElement {
    var onPress: (@MainActor () -> Void)?

    override func accessibilityPerformPress() -> Bool {
        guard let onPress else { return false }
        Task { @MainActor in onPress() }
        return true
    }
}
