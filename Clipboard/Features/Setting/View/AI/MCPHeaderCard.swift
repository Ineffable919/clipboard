//
//  MCPHeaderCard.swift
//  Clipboard
//

import SwiftUI

struct MCPHeaderCard: View {
    @Binding var isEnabled: Bool
    let enabledToolCount: Int

    private var status: LocalizedStringResource {
        isEnabled ? .mcpRunning(enabledToolCount) : .mcpStopped
    }

    var body: some View {
        HStack(spacing: Const.space12) {
            VStack(alignment: .leading, spacing: Const.space4) {
                Text("MCP")
                    .font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .onChange(of: isEnabled) { _, newValue in
                    MCPEnableFlag.setEnabled(newValue)
                }
        }
        .padding(Const.space16)
        .settingsStyle()
    }
}
