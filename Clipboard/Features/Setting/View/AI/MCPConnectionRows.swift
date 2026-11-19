//
//  MCPConnectionCard.swift
//  Clipboard
//
//  Created by crown on 2026/11/19
//

import SwiftUI

// MARK: - MCPConnectionCard

/// 连接信息：地址与令牌，修改端口、重新生成令牌各走一层弹窗
struct MCPConnectionCard: View {
    let server: MCPServer

    @State private var showPortSheet = false
    @State private var confirmRegenerate = false
    @State private var showToken = false

    var body: some View {
        VStack(alignment: .leading, spacing: Const.space6) {
            Text(.mcpConnectionInfo)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Const.space4)

            VStack(alignment: .leading, spacing: 0) {
                addressRow
                if server.status == .failed {
                    Text(.mcpPortUnavailable)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.leading, Const.space10 + Const.space6 + Const.space32 + Const.space8)
                        .padding(.bottom, Const.space8)
                }
                Divider()
                    .padding(.horizontal, Const.space10)
                tokenRow
            }
            .settingsStyle()
        }
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
        row(title: .mcpAddress) {
            Circle()
                .fill(statusColor)
                .frame(width: Const.space6, height: Const.space6)
            CopyValue(shown: server.endpoint, copied: server.endpoint)
            IconButton(systemName: "square.and.pencil", label: .mcpChange) {
                showPortSheet = true
            }
        }
    }

    private var tokenRow: some View {
        row(title: .mcpToken) {
            CopyValue(shown: showToken ? server.token : maskedToken, copied: server.token)
            IconButton(systemName: showToken ? "eye.slash" : "eye", label: .mcpToken) {
                showToken.toggle()
            }
            IconButton(systemName: "arrow.triangle.2.circlepath", label: .mcpRegenerate) {
                confirmRegenerate = true
            }
        }
    }

    private func row(
        title: LocalizedStringResource,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack(spacing: Const.space6) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: Const.space32 + Const.space8, alignment: .leading)
            content()
        }
        .padding(.horizontal, Const.space10)
        .frame(minHeight: Const.space32 + Const.space8)
    }

    private var maskedToken: String {
        MCPToken.prefix + String(repeating: "•", count: 8) + server.token.suffix(4)
    }

    private var statusColor: Color {
        switch server.status {
        case .running: .green
        case .failed: .red
        case .stopped: .secondary
        }
    }
}

// MARK: - CopyValue

private struct CopyValue: View {
    let shown: String
    let copied: String

    var body: some View {
        Button {
            NSPasteboard.copy(copied)
        } label: {
            Text(verbatim: shown)
                .font(.body.monospaced())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.vertical, Const.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - IconButton

private struct IconButton: View {
    let systemName: String
    let label: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.medium))
                .frame(width: Const.space24, height: Const.space24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

// MARK: - MCPPortSheet

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

#Preview("Running") {
    MCPConnectionCard(server: MCPServer(previewStatus: .running))
        .padding(Const.space24)
        .frame(width: Const.settingWidth - 150)
}

#Preview("Port unavailable") {
    MCPConnectionCard(server: MCPServer(previewStatus: .failed))
        .padding(Const.space24)
        .frame(width: Const.settingWidth - 150)
}

#Preview("Port sheet") {
    MCPPortSheet(server: MCPServer(previewStatus: .running))
}
