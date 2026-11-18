//
//  MCPHeaderCard.swift
//  Clipboard
//
//  Created by crown on 2026/8/19
//

import SwiftUI

struct MCPHeaderCard: View {
    @Binding var isEnabled: Bool

    @State private var showDetails = false

    var server: MCPServer = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: Const.space4) {
            titleRow

            Text(.mcpDesc)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Const.space10)
        .settingsStyle()
        .sheet(isPresented: $showDetails) {
            MCPConnectionDetails(server: server)
        }
    }

    private var titleRow: some View {
        HStack(spacing: Const.space8) {
            Text(.mcpEnable)
            Spacer()

            if isEnabled {
                Button(.mcpDetails) { showDetails = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

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

// MARK: - Connection details

private struct MCPConnectionDetails: View {
    @Environment(\.dismiss) private var dismiss
    let server: MCPServer

    @State private var showPortSheet = false
    @State private var confirmRegenerate = false
    @State private var showToken = false

    var body: some View {
        VStack(alignment: .leading, spacing: Const.space16) {
            Text(.mcpDetailsTitle)
                .font(.title3.bold())

            Grid(alignment: .leading, horizontalSpacing: Const.space10, verticalSpacing: Const.space6) {
                addressRow
                if server.status == .failed {
                    Text(.mcpPortUnavailable)
                        .foregroundStyle(.red)
                        .padding(.leading, Const.space12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .gridCellUnsizedAxes(.horizontal)
                }
                Divider()
                    .gridCellUnsizedAxes(.horizontal)
                tokenRow
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.horizontal, Const.space12)
            .padding(.vertical, Const.space8)
            .background(.fill.quaternary, in: .rect(cornerRadius: Const.space10))

            Button(.close) { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(Const.space24)
        .frame(width: 480)
        .sheet(isPresented: $showPortSheet) {
            MCPPortSheet(server: server)
        }
        .alert(Text(.mcpRegenerateTitle), isPresented: $confirmRegenerate) {
            Button(.cancelButton, role: .cancel) {}
            Button(.mcpRegenerate, role: .destructive) {
                showToken = false
                server.regenerateToken()
            }
        } message: {
            Text(.mcpRegenerateMessage)
        }
    }

    private var addressRow: some View {
        GridRow {
            HStack(spacing: Const.space6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: Const.space6, height: Const.space6)

                Text(server.endpoint)
                    .font(.callout)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: Const.space24, alignment: .leading)

            Button(.mcpCopy) {
                NSPasteboard.copy(server.endpoint)
            }

            Button(.mcpChange) {
                showPortSheet = true
            }
        }
    }

    private var maskedToken: String {
        MCPToken.prefix + String(repeating: "•", count: 8) + server.token.suffix(4)
    }

    private var tokenRow: some View {
        GridRow {
            HStack(spacing: Const.space8) {
                Text(.mcpToken)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize()

                Text(verbatim: showToken ? server.token : maskedToken)
                    .font(.callout)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                tokenVisibilityButton
            }

            Button(.mcpCopy) {
                NSPasteboard.copy(server.token)
            }

            Button(.mcpRegenerate) {
                confirmRegenerate = true
            }
        }
    }

    private var tokenVisibilityButton: some View {
        Button {
            showToken.toggle()
        } label: {
            Image(systemName: showToken ? "eye.slash" : "eye")
                .foregroundStyle(.secondary)
                .frame(width: Const.space20, height: Const.space24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(.mcpToken, isOn: $showToken)
                .toggleStyle(.switch)
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
    MCPHeaderCard(isEnabled: $isEnabled)
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
