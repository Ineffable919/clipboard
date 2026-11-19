//
//  MCPHeaderCard.swift
//  Clipboard
//
//  Created by crown on 2026/8/19
//

import SwiftUI

struct MCPHeaderCard: View {
    @Binding var isEnabled: Bool

    var server: MCPServer = .shared

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
                MCPAddressRow(server: server)
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
    MCPHeaderCard(
        isEnabled: $isEnabled,
        server: MCPServer(previewStatus: .running)
    )
    .padding(Const.space24)
    .frame(width: Const.settingWidth - 150)
}

#Preview("Port unavailable") {
    @Previewable @State var isEnabled = true
    MCPHeaderCard(
        isEnabled: $isEnabled,
        server: MCPServer(previewStatus: .failed)
    )
    .padding(Const.space24)
    .frame(width: Const.settingWidth - 150)
}

#Preview("Disabled") {
    @Previewable @State var isEnabled = false
    MCPHeaderCard(isEnabled: $isEnabled)
        .padding(Const.space24)
        .frame(width: Const.settingWidth - 150)
}
