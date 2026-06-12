import Foundation

enum MCPEnableFlag {
    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: ClipboardPaths.mcpEnableFlag)
    }

    static func setEnabled(_ enabled: Bool) {
        if enabled {
            FileManager.default.createFile(
                atPath: ClipboardPaths.mcpEnableFlag,
                contents: nil
            )
        } else {
            try? FileManager.default.removeItem(
                atPath: ClipboardPaths.mcpEnableFlag
            )
        }
    }
}
