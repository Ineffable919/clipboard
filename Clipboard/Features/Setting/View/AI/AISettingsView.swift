//
//  AISettingsView.swift
//  Clipboard
//
//  Created by crown on 2026/6/2
//

import SwiftUI

// MARK: - MCPClientInfo

struct MCPClientInfo: Identifiable {
    var id: String {
        name
    }

    let name: String
    let icon: String
    let subtitle: LocalizedStringResource
    let command: String
    let footer: LocalizedStringResource?
    let configNote: String?
}

// MARK: - AISettingsView

struct AISettingsView: View {
    @State private var isEnabled: Bool
    @State private var enabledTools: Set<String>
    @State private var selectedClient: MCPClientInfo?
    private let server: MCPServer

    init(
        initialEnabled: Bool = MCPEnableFlag.isEnabled,
        server: MCPServer = .shared
    ) {
        self.server = server
        _isEnabled = State(initialValue: initialEnabled)
        _enabledTools = State(
            initialValue: Set(MCPToolInfo.all.map(\.name)).subtracting(
                MCPDisabledTools.load()
            )
        )
    }

    private var clients: [MCPClientInfo] {
        let url = server.endpoint
        let cliSubtitle = LocalizedStringResource.mcpCliSub
        let configSubtitle = LocalizedStringResource.mcpConfigSub
        let bridgeCommand = """
            {
              "mcpServers": {
                "clipboard": {
                  "command": "npx",
                  "args": ["-y", "mcp-remote", "\(url)"]
                }
              }
            }
            """
        let urlCommand = """
            {
              "mcpServers": {
                "clipboard": {
                  "url": "\(url)"
                }
              }
            }
            """
        let vsCodeCommand = """
            {
              "servers": {
                "clipboard": {
                  "type": "http",
                  "url": "\(url)"
                }
              }
            }
            """
        return [
            MCPClientInfo(
                name: "Claude Desktop",
                icon: "MCPClaudeIcon",
                subtitle: configSubtitle,
                command: bridgeCommand,
                footer: .mcpNodeNote,
                configNote:
                    "~/Library/Application Support/Claude/claude_desktop_config.json"
            ),
            MCPClientInfo(
                name: "Claude Code",
                icon: "MCPClaudeIcon",
                subtitle: cliSubtitle,
                command:
                    "claude mcp add --transport http clipboard \(url)",
                footer: .mcpClaudeFooter,
                configNote: nil
            ),
            MCPClientInfo(
                name: "Codex",
                icon: "MCPCodexIcon",
                subtitle: cliSubtitle,
                command: "codex mcp add clipboard \\\n  --url \(url)",
                footer: nil,
                configNote: nil
            ),
            MCPClientInfo(
                name: "Cursor",
                icon: "MCPCursorIcon",
                subtitle: configSubtitle,
                command: urlCommand,
                footer: nil,
                configNote: "~/.cursor/mcp.json"
            ),
            MCPClientInfo(
                name: "VS Code",
                icon: "MCPVSCodeIcon",
                subtitle: configSubtitle,
                command: vsCodeCommand,
                footer: nil,
                configNote: "~/.vscode/mcp.json"
            )
        ]
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Const.space12) {
                MCPHeaderCard(
                    isEnabled: $isEnabled,
                    enabledToolCount: enabledTools.count,
                    server: server
                )
                if isEnabled {
                    MCPToolsSection(enabledTools: $enabledTools)

                    HStack {
                        Spacer()
                        MCPClientMenu(
                            title: String(localized: .mcpConnectTools),
                            clients: clients
                        ) { client in
                            selectedClient = client
                        }
                        .fixedSize()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding([.horizontal, .bottom], Const.space24)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .sheet(item: $selectedClient) { client in
            MCPClientDetailSheet(client: client)
        }
    }
}

// MARK: - Tools Section

extension Binding where Value == Set<String> {
    fileprivate subscript(contains element: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue.contains(element) },
            set: { newValue in
                var updated = wrappedValue
                if newValue {
                    updated.insert(element)
                } else {
                    updated.remove(element)
                }
                wrappedValue = updated
            }
        )
    }
}

private struct MCPToolsSection: View {
    @Binding var enabledTools: Set<String>

    private func isEnabledBinding(for name: String) -> Binding<Bool> {
        $enabledTools[contains: name]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Const.space12) {
            Text(.mcpExposedTools)
                .font(.subheadline.bold())

            VStack(spacing: 0) {
                ForEach(Array(MCPToolInfo.all.enumerated()), id: \.element.id) { index, tool in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, Const.space16)
                    }
                    MCPToolRow(
                        tool: tool,
                        isEnabled: isEnabledBinding(for: tool.name)
                    )
                }
            }
            .settingsStyle()
            .onChange(of: enabledTools) { _, newValue in
                MCPDisabledTools.save(
                    Set(MCPToolInfo.all.map(\.name)).subtracting(newValue)
                )
            }
        }
    }
}

// MARK: - MCPClientDetailSheet

private struct MCPClientDetailSheet: View {
    let client: MCPClientInfo
    @Environment(\.dismiss) private var dismiss
    @FocusState private var cancelFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            clientIcon

            Text(.mcpConnectFormat(client.name))
                .font(.title2.bold())
                .padding(.bottom, Const.space4)

            Text(client.subtitle)
                .padding(.bottom, Const.space16)

            MCPCommandBlock(command: client.command)
                .padding(
                    .bottom,
                    client.configNote != nil ? Const.space8 : Const.space16
                )

            if let note = client.configNote {
                HStack(spacing: Const.space4) {
                    Text(.mcpPasteInto)
                    Button {
                        NSPasteboard.copy(note)
                    } label: {
                        Text(note)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .help(note)
                }
                .padding(.bottom, Const.space16)
            }

            if let footer = client.footer {
                Text(footer)
                    .padding(.bottom, Const.space16)
            }

            HStack {
                Spacer()
                Button(.cancelButton) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .focused($cancelFocused)
            }
        }
        .padding(Const.space24)
        .frame(width: 440)
        .defaultFocus($cancelFocused, true)
    }

    private var clientIcon: some View {
        Image(client.icon)
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .clipShape(.rect(cornerRadius: 8))
            .padding(.bottom, Const.space16)
    }
}

// MARK: - MCPCommandBlock

/// 可选中、可一键复制的等宽命令/配置块
private struct MCPCommandBlock: View {
    let command: String

    var body: some View {
        Text(command)
            .font(.callout.monospaced())
            .lineSpacing(3)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Const.space12)
            .padding(.leading, Const.space16)
            .padding(.trailing, Const.space32 + Const.space8)
            .background(
                .quaternary,
                in: RoundedRectangle(cornerRadius: Const.space8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Const.space8)
                    .stroke(Color.primary.opacity(0.06))
            )
            .overlay(alignment: .topTrailing) {
                copyButton
            }
    }

    private var copyButton: some View {
        Button {
            NSPasteboard.copy(command)
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: Const.space32, height: Const.space32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(Text(.mcpCopy))
        .accessibilityLabel(Text(.mcpCopy))
    }
}

// MARK: - MCPToolRow

private struct MCPToolRow: View {
    let tool: MCPToolInfo
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: Const.space12) {
            Circle()
                .fill(isEnabled ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
                .animation(.easeInOut(duration: 0.2), value: isEnabled)

            VStack(alignment: .leading, spacing: 4) {
                Text(tool.name)
                Text(tool.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Const.space12)

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
        }
        .padding(.horizontal, Const.space16)
        .padding(.vertical, Const.space10)
    }
}

#Preview("Disabled") {
    AISettingsView(initialEnabled: false)
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}

#Preview("Port unavailable") {
    AISettingsView(
        initialEnabled: true,
        server: MCPServer(previewStatus: .failed)
    )
    .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}

#Preview("Enabled") {
    AISettingsView(initialEnabled: true)
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}

#Preview("Command block") {
    VStack(spacing: Const.space16) {
        MCPCommandBlock(
            command: "claude mcp add --transport http clipboard http://127.0.0.1:38417/mcp"
        )
        MCPCommandBlock(command: """
        {
          "mcpServers": {
            "clipboard": {
              "url": "http://127.0.0.1:38417/mcp"
            }
          }
        }
        """)
    }
    .padding(Const.space24)
    .frame(width: 440)
}
