//
//  NSApplication+Extension.swift
//  Clipboard
//

import AppKit

extension NSApplication {
    func relaunch() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            Task { @MainActor in
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
