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
        HStack(spacing: Const.space12) {
            settingsToggle(
                title: String(
                    localized: .settingAboutAutomaticallyCheckUpdates
                ),
                isOn: $automaticallyChecksForUpdates
            )
            .onChange(of: automaticallyChecksForUpdates) { _, _ in
                updater.automaticallyChecksForUpdates =
                    automaticallyChecksForUpdates
            }

            settingsToggle(
                title: String(
                    localized: .settingAboutAutomaticallyDownloadUpdates
                ),
                isOn: $automaticallyDownloadsUpdates
            )
            .disabled(!automaticallyChecksForUpdates)
            .onChange(of: automaticallyDownloadsUpdates) { _, _ in
                updater.automaticallyDownloadsUpdates =
                    automaticallyDownloadsUpdates
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func settingsToggle(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(title)
        }
        .help(title)
    }
}

#Preview {
    let updater = (AppDelegate.shared?.updaterController.updater)!
    UpdaterSettingsView(updater: updater)
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
