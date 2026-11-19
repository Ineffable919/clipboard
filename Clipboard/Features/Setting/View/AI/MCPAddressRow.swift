//
//  MCPAddressRow.swift
//  Clipboard
//
//  Created by crown on 2026/11/19
//

import SwiftUI

// MARK: - MCPAddressRow

/// 服务地址：状态点、地址、复制与更改，嵌在设置卡片内
struct MCPAddressRow: View {
    let server: MCPServer

    @State private var showPortSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.horizontal, Const.space10)
            HStack(spacing: Const.space6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: Const.space6, height: Const.space6)
                Text(verbatim: server.endpoint)
                    .font(.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .textSelection(.enabled)
                Spacer(minLength: Const.space8)
                SystemButton(title: .mcpCopy) {
                    NSPasteboard.copy(server.endpoint)
                }
                SystemButton(title: .mcpChange) {
                    showPortSheet = true
                }
            }
            .padding(.horizontal, Const.space10)
            .frame(minHeight: Const.space32 + Const.space8)
            if server.status == .failed {
                Text(.mcpPortUnavailable)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, Const.space10 + Const.space6 + Const.space6)
                    .padding(.bottom, Const.space8)
            }
        }
        .sheet(isPresented: $showPortSheet) {
            MCPPortSheet(server: server)
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

#Preview("Port sheet") {
    MCPPortSheet(server: MCPServer(previewStatus: .running))
}
