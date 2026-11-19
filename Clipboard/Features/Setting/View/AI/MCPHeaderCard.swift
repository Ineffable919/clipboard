//
//  MCPHeaderCard.swift
//  Clipboard
//
//  Created by crown on 2026/8/19
//

import SwiftUI

struct MCPHeaderCard: View {
    @Binding var isEnabled: Bool

    @AppStorage(PrefKey.mcpMaskSecrets.rawValue)
    private var maskSecrets = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Const.space4) {
                titleRow

                Text(.mcpDesc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Const.space10)

            if isEnabled {
                Divider()
                    .padding(.horizontal, Const.space10)

                PrivacyToggleRow(
                    title: String(localized: .mcpMaskSecrets),
                    subtitle: String(localized: .mcpMaskSecretsDesc),
                    isOn: $maskSecrets
                )
                .padding(.horizontal, Const.space10)
            }
        }
        .settingsStyle()
    }

    private var titleRow: some View {
        HStack(spacing: Const.space8) {
            Text(.mcpEnable)
            Spacer()

            Toggle(.mcpEnable, isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .onChange(of: isEnabled) { _, newValue in
                    MCPEnableFlag.setEnabled(newValue)
                }
        }
        .frame(minHeight: Const.space24)
    }
}

#Preview("Enabled") {
    @Previewable @State var isEnabled = true
    MCPHeaderCard(isEnabled: $isEnabled)
        .padding(Const.space24)
        .frame(width: Const.settingWidth - 150)
}

#Preview("Disabled") {
    @Previewable @State var isEnabled = false
    MCPHeaderCard(isEnabled: $isEnabled)
        .padding(Const.space24)
        .frame(width: Const.settingWidth - 150)
}
