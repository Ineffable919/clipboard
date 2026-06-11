import SwiftUI

// MARK: - MCPClientInfo

private struct MCPClientInfo: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let iconColor: Color
    let appIcon: NSImage?
    let subtitle: String
    let command: String
    let footer: String?
    let configNote: String?

    static func loadAppIcon(bundleID: String?, appName: String?) -> NSImage? {
        var appPath: String?
        if let bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        {
            appPath = url.path
        } else if let appName {
            let path = "/Applications/\(appName).app"
            if FileManager.default.fileExists(atPath: path) {
                appPath = path
            }
        }
        guard let appPath else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: appPath)
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }
}

// MARK: - MCPToolInfo

private struct MCPToolInfo: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let color: Color

    static let all: [MCPToolInfo] = MCPToolDefinition.all.map {
        .init(
            name: $0.name,
            description: $0.localizedDescription,
            icon: $0.icon,
            color: Color(hex: $0.colorHex)
        )
    }
}

extension MCPToolDefinition {
    fileprivate var localizedDescription: String {
        switch name {
        case "search_clipboard": String(localized: .mcpToolDescSearchClipboard)
        case "write_clipboard": String(localized: .mcpToolDescWriteClipboard)
        case "list_tags": String(localized: .mcpToolDescListCategories)
        default: description
        }
    }
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
        let cliSubtitle = String(localized: .mcpClientSubtitleCLI)
        let configSubtitle = String(localized: .mcpClientSubtitleConfig)
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
                icon: "sparkle",
                iconColor: Color(hex: "E8714A"),
                appIcon: MCPClientInfo.loadAppIcon(
                    bundleID: "com.anthropic.claudefordesktop",
                    appName: "Claude"
                ),
                subtitle: configSubtitle,
                command: configCommand,
                footer: nil,
                configNote: "~/Library/Application Support/Claude/claude_desktop_config.json"
            ),
            MCPClientInfo(
                name: "Claude Code",
                icon: "terminal",
                iconColor: Color(hex: "E8714A"),
                appIcon: MCPClientInfo.loadAppIcon(
                    bundleID: "com.anthropic.claudefordesktop",
                    appName: "Claude"
                ),
                subtitle: cliSubtitle,
                command: "claude mcp add --transport stdio clipboard -- \(helperPath)",
                footer: String(localized: .mcpClientFooterClaudeCode),
                configNote: nil
            ),
            MCPClientInfo(
                name: "Codex",
                icon: "bolt.fill",
                iconColor: Color(hex: "5B8EF0"),
                appIcon: MCPClientInfo.loadAppIcon(
                    bundleID: "com.openai.codex",
                    appName: "Codex"
                ),
                subtitle: cliSubtitle,
                command: "codex mcp add clipboard -- \(helperPath)",
                footer: nil,
                configNote: nil
            ),
            MCPClientInfo(
                name: "Cursor",
                icon: "cursorarrow.rays",
                iconColor: Color(hex: "1A1A1A"),
                appIcon: MCPClientInfo.loadAppIcon(
                    bundleID: "com.todesktop.230313mzl4w4u92",
                    appName: "Cursor"
                ),
                subtitle: configSubtitle,
                command: configCommand,
                footer: nil,
                configNote: "~/.cursor/mcp.json"
            ),
            MCPClientInfo(
                name: "VS Code",
                icon: "chevron.left.forwardslash.chevron.right",
                iconColor: Color(hex: "007ACC"),
                appIcon: MCPClientInfo.loadAppIcon(
                    bundleID: "com.microsoft.VSCode",
                    appName: "Visual Studio Code"
                ),
                subtitle: configSubtitle,
                command: vsCodeCommand,
                footer: nil,
                configNote: "~/.vscode/mcp.json"
            ),
        ]
    }()

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Const.space12) {
                headerCard
                if isEnabled {
                    HStack {
                        Spacer()
                        Menu {
                            ForEach(Self.clients) { client in
                                Button {
                                    selectedClient = client
                                } label: {
                                    Label {
                                        Text(client.name)
                                    } icon: {
                                        if let appIcon = client.appIcon {
                                            Image(nsImage: appIcon)
                                        } else {
                                            Image(systemName: client.icon)
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text(String(localized: .mcpConnectAITools))
                                .font(.system(size: 13, design: .default))
                        }
                        .fixedSize()
                    }
                    toolsSection
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

    // MARK: - Header Card

    @ViewBuilder private var headerCard: some View {
        HStack(spacing: Const.space12) {
            VStack(alignment: .leading, spacing: Const.space4) {
                Text("MCP")
                    .font(.headline)
                Text(
                    isEnabled
                        ? "stdio · @clipboard/mcp · \(enabledTools.count) tools exposed"
                        : "server stopped · 0 tools exposed"
                )
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

    // MARK: - Tools Section

    @ViewBuilder private var toolsSection: some View {
        VStack(alignment: .leading, spacing: Const.space12) {
            Text(String(localized: "mcpExposedTools", table: "Localizable"))
                .font(.subheadline.bold())

            VStack(spacing: 0) {
                ForEach(Array(MCPToolInfo.all.enumerated()), id: \.element.id) {
                    index,
                    tool in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, Const.space24)
                    }
                    MCPToolRow(
                        tool: tool,
                        isToolEnabled: enabledTools.contains(tool.name)
                    ) { enabled in
                        if enabled {
                            enabledTools.insert(tool.name)
                        } else {
                            enabledTools.remove(tool.name)
                        }
                        MCPDisabledTools.save(
                            Set(MCPToolInfo.all.map(\.name)).subtracting(
                                enabledTools
                            )
                        )
                    }
                }
            }
            .settingsStyle()
        }
    }
}

// MARK: - MCPClientDetailSheet

private struct MCPClientDetailSheet: View {
    let client: MCPClientInfo
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            clientIcon
                .padding(.bottom, Const.space16)

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
                    Text(.mcpClaudeDesktopConfigPath)
                    Text(note)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
    }

    @ViewBuilder private var clientIcon: some View {
        if let appIcon = client.appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(client.iconColor)
                    .frame(width: 40, height: 40)
                Image(systemName: client.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder private var commandBlock: some View {
        ZStack(alignment: .topTrailing) {
            Text(client.command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
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
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark.circle" : "doc.on.doc")
                    .font(.callout)
                    .foregroundStyle(copied ? Color.accentColor : .secondary)
                    .frame(width: Const.space32, height: Const.space32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: copied)
        }
    }
}

// MARK: - MCPToolRow

private struct MCPToolRow: View {
    let tool: MCPToolInfo
    let isToolEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: Const.space12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isToolEnabled
                            ? tool.color.opacity(0.12)
                            : Color.secondary.opacity(0.1)
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: tool.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        isToolEnabled ? tool.color : Color.secondary
                    )
            }
            .animation(.easeInOut(duration: 0.2), value: isToolEnabled)

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

            Toggle(
                "",
                isOn: Binding(get: { isToolEnabled }, set: { onToggle($0) })
            )
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
