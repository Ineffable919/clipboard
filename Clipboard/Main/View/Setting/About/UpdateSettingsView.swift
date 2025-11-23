//
//  UpdateSettingsView.swift
//  Clipboard
//
//  Created by crown on 2025/11/19.
//

import Sparkle
import SwiftUI

struct UpdaterSettingsView: View {
    private let updater: SPUUpdater

    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool

    init(updater: SPUUpdater) {
        self.updater = updater
        automaticallyChecksForUpdates =
            updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates =
            updater.automaticallyDownloadsUpdates
    }

    var body: some View {
        HStack(spacing: 20) {
            Toggle(
                "自动检查更新",
                isOn: $automaticallyChecksForUpdates,
            )
            .onChange(of: automaticallyChecksForUpdates) {
                updater.automaticallyChecksForUpdates =
                    automaticallyChecksForUpdates
            }

            Toggle(
                "自动下载更新",
                isOn: $automaticallyDownloadsUpdates,
            )
            .disabled(!automaticallyChecksForUpdates)
            .onChange(of: automaticallyDownloadsUpdates) {
                updater.automaticallyDownloadsUpdates =
                    automaticallyDownloadsUpdates
            }
        }
    }
}

#Preview {
    let updater = (AppDelegate.shared?.updaterController.updater)!
    UpdaterSettingsView(updater: updater)
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
