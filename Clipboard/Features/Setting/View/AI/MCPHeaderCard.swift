//
//  MCPHeaderCard.swift
//  Clipboard
//
//  Created by crown on 2026/8/19
//

import SwiftUI

struct MCPHeaderCard: View {
    @Binding var isEnabled: Bool
    let enabledToolCount: Int

    @State private var showPortSheet = false

    var server: MCPServer = .shared
    private var failed: Bool { isEnabled && server.status == .failed }

    private var status: LocalizedStringResource {
        guard isEnabled else { return .mcpStopped }
        return failed ? .mcpPortUnavailable : .mcpRunning(enabledToolCount)
    }

    var body: some View {
        VStack(spacing: 0) {
            titleRow
            if isEnabled {
                Divider()
                    .padding(.vertical, Const.space12)
                addressRow
            }
        }
        .padding(Const.space16)
        .settingsStyle()
        .sheet(isPresented: $showPortSheet) {
            MCPPortSheet(server: server)
        }
    }

    private var titleRow: some View {
        HStack(spacing: Const.space12) {
            VStack(alignment: .leading, spacing: Const.space4) {
                Text("MCP")
                    .font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(failed ? .red : .secondary)
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
    }

    private var addressRow: some View {
        HStack(spacing: Const.space8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(server.endpoint)
                .textSelection(.enabled)
                .lineLimit(1)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(server.endpoint, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(.mcpChange) {
                showPortSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    private var statusColor: Color {
        switch server.status {
        case .running: .green
        case .failed: .red
        case .stopped: .secondary
        }
    }
}

// MARK: - Port sheet

private struct MCPPortSheet: View {
    @Environment(\.dismiss) private var dismiss
    let server: MCPServer
    @State private var text: String

    init(server: MCPServer) {
        self.server = server
        _text = State(initialValue: String(server.port))
    }

    private var port: Int? {
        Int(text.trimmingCharacters(in: .whitespaces))
            .flatMap { MCPServer.portRange.contains($0) ? $0 : nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Const.space12) {
            Text(.mcpPortSheetTitle)
                .font(.title3.bold())

            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.title3.monospaced())
                .onSubmit(apply)

            Text(.mcpPortSheetNote)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button(.cancelButton) { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button(.mcpChange, action: apply)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(port == nil)
            }
        }
        .padding(Const.space24)
        .frame(width: 360)
    }

    private func apply() {
        guard let port else { return }
        server.setPort(port)
        dismiss()
    }
}

#Preview("Enabled") {
    @Previewable @State var isEnabled = true
    MCPHeaderCard(isEnabled: $isEnabled, enabledToolCount: 3)
        .padding(Const.space24)
        .frame(width: Const.settingWidth - 150)
}

#Preview("Port unavailable") {
    @Previewable @State var isEnabled = true
    MCPHeaderCard(
        isEnabled: $isEnabled,
        enabledToolCount: 3,
        server: MCPServer(previewStatus: .failed)
    )
    .padding(Const.space24)
    .frame(width: Const.settingWidth - 150)
}

#Preview("Disabled") {
    @Previewable @State var isEnabled = false
    MCPHeaderCard(isEnabled: $isEnabled, enabledToolCount: 0)
        .padding(Const.space24)
        .frame(width: Const.settingWidth - 150)
}
