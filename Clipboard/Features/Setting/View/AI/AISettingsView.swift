import SwiftUI

// MARK: - MCPClientInfo

private struct MCPClientInfo: Identifiable {
    var id: String {
        name
    }

    let name: String
    let iconURL: String
    let subtitle: String
    let command: String
    let footer: String?
    let configNote: String?
}

// MARK: - AISettingsView

struct AISettingsView: View {
    @State private var isEnabled: Bool
    @State private var enabledTools: Set<String>
    @State private var selectedClient: MCPClientInfo?

    init(initialEnabled: Bool = MCPEnableFlag.isEnabled) {
        _isEnabled = State(initialValue: initialEnabled)
        _enabledTools = State(
            initialValue: Set(MCPToolInfo.all.map(\.name)).subtracting(
                MCPDisabledTools.load()
            )
        )
    }

    private static let clients: [MCPClientInfo] = {
        let helperPath = Bundle.main.bundleURL
            .appending(path: "Contents/MacOS/clipmcp")
            .path
        let iconBase = "https://raw.githubusercontent.com/Ineffable919/clipboard/"
            + "c1d53491f24ff028946e287ec09b9943e5a11caf/Clipboard/Resource/Assets.xcassets"
        let cliSubtitle = String(localized: .mcpCliSub)
        let configSubtitle = String(localized: .mcpConfigSub)
        let configCommand = """
        {
          "mcpServers": {
            "clipboard": {
              "command": "\(helperPath)"
            }
          }
        }
        """
        let vsCodeCommand = """
        {
          "servers": {
            "clipboard": {
              "type": "stdio",
              "command": "\(helperPath)"
            }
          }
        }
        """
        return [
            MCPClientInfo(
                name: "Claude Desktop",
                iconURL: "\(iconBase)/MCPClaudeIcon.imageset/claude.png",
                subtitle: configSubtitle,
                command: configCommand,
                footer: nil,
                configNote:
                "~/Library/Application Support/Claude/claude_desktop_config.json"
            ),
            MCPClientInfo(
                name: "Claude Code",
                iconURL: "\(iconBase)/MCPClaudeIcon.imageset/claude.png",
                subtitle: cliSubtitle,
                command:
                "claude mcp add --transport stdio clipboard -- \(helperPath)",
                footer: String(localized: .mcpClaudeFooter),
                configNote: nil
            ),
            MCPClientInfo(
                name: "Codex",
                iconURL: "\(iconBase)/MCPCodexIcon.imageset/codex.png",
                subtitle: cliSubtitle,
                command: "codex mcp add clipboard -- \(helperPath)",
                footer: nil,
                configNote: nil
            ),
            MCPClientInfo(
                name: "Cursor",
                iconURL: "\(iconBase)/MCPCursorIcon.imageset/cursor.png",
                subtitle: configSubtitle,
                command: configCommand,
                footer: nil,
                configNote: "~/.cursor/mcp.json"
            ),
            MCPClientInfo(
                name: "VS Code",
                iconURL: "\(iconBase)/MCPVSCodeIcon.imageset/vscode.png",
                subtitle: configSubtitle,
                command: vsCodeCommand,
                footer: nil,
                configNote: "~/.vscode/mcp.json"
            )
        ]
    }()

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Const.space12) {
                MCPHeaderCard(isEnabled: $isEnabled, enabledToolCount: enabledTools.count)
                if isEnabled {
                    HStack {
                        Spacer()
                        Menu {
                            ForEach(Self.clients) { client in
                                Button {
                                    selectedClient = client
                                } label: {
                                    Text(client.name)
                                }
                            }
                        } label: {
                            Text(String(localized: .mcpConnectTools))
                                .font(.system(size: 13, design: .default))
                        }
                        .fixedSize()
                    }
                    MCPToolsSection(enabledTools: $enabledTools)
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

private extension Binding where Value == Set<String> {
    subscript(contains element: String) -> Binding<Bool> {
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
            Text(String(localized: "mcpExposedTools", table: "Localizable"))
                .font(.subheadline.bold())

            VStack(spacing: 0) {
                ForEach(Array(MCPToolInfo.all.enumerated()), id: \.element.id) { index, tool in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, Const.space24)
                    }
                    MCPToolRow(tool: tool, isEnabled: isEnabledBinding(for: tool.name))
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
    @State private var iconImage: NSImage?
    @State private var isIconLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            clientIcon

            Text(String(localized: .mcpConnectFormat(client.name)))
                .font(.title2.bold())
                .padding(.bottom, Const.space4)

            Text(client.subtitle)
                .padding(.bottom, Const.space16)

            commandBlock
                .padding(
                    .bottom,
                    client.configNote != nil ? Const.space8 : Const.space16
                )

            if let note = client.configNote {
                HStack(spacing: Const.space4) {
                    Text(.mcpPasteInto)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(note, forType: .string)
                    } label: {
                        Text(note)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
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
                Button(String(localized: .cancelButton)) {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(Const.space24)
        .frame(width: 440)
        .task(id: client.iconURL) {
            iconImage = nil
            isIconLoading = true
            let image = await MCPClientIconLoader.load(client.iconURL)
            guard !Task.isCancelled else { return }
            iconImage = image
            isIconLoading = false
        }
    }

    @ViewBuilder private var clientIcon: some View {
        if isIconLoading {
            ProgressView()
                .controlSize(.small)
                .frame(width: 40, height: 40)
                .padding(.bottom, Const.space16)
        } else if let iconImage {
            Image(nsImage: iconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 8))
                .padding(.bottom, Const.space16)
        }
    }

    private var commandBlock: some View {
        ZStack(alignment: .topTrailing) {
            Text(client.command)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Const.space12)
                .padding(.vertical, Const.space12)
                .padding(.trailing, Const.space32)
                .background(
                    .quaternary,
                    in: RoundedRectangle(cornerRadius: Const.space8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Const.space8)
                        .stroke(Color.primary.opacity(0.06))
                )

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(client.command, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: Const.space32, height: Const.space32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - MCPToolRow

private struct MCPToolRow: View {
    let tool: MCPToolInfo
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: Const.space12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isEnabled
                            ? tool.color.opacity(0.12)
                            : Color.secondary.opacity(0.1)
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: tool.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        isEnabled ? tool.color : Color.secondary
                    )
            }
            .animation(.easeInOut(duration: 0.2), value: isEnabled)

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.system(size: 12, design: .default))
                Text(tool.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(tool.description)
            }

            Spacer()

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

#Preview("Enabled") {
    AISettingsView(initialEnabled: true)
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
