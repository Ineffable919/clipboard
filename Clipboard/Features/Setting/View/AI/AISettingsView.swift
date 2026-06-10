import SwiftUI

// MARK: - Tool metadata

private struct MCPToolInfo: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let color: Color

    static let all: [MCPToolInfo] = MCPToolDefinition.all.map {
        .init(name: $0.name, description: $0.localizedDescription, icon: $0.icon, color: Color(hex: $0.colorHex))
    }
}

private extension MCPToolDefinition {
    var localizedDescription: String {
        switch name {
        case "search_clipboard": String(localized: .mcpToolDescSearchClipboard)
        case "write_clipboard":  String(localized: .mcpToolDescWriteClipboard)
        case "list_tags":        String(localized: .mcpToolDescListCategories)
        default:                 description
        }
    }
}

// MARK: - AISettingsView

struct AISettingsView: View {
    @State private var isEnabled: Bool
    @State private var selectedClientIndex = 0
    @State private var copiedKey: String? = nil
    @State private var enabledTools: Set<String>

    init(initialEnabled: Bool = MCPEnableFlag.isEnabled) {
        _isEnabled = State(initialValue: initialEnabled)
        _enabledTools = State(initialValue: Set(MCPToolInfo.all.map(\.name)).subtracting(MCPDisabledTools.load()))
    }

    private var helperPath: String {
        Bundle.main.bundleURL
            .appending(path: "Contents/MacOS/clipmcp")
            .path
    }

    private var clients: [(label: String, content: String, note: String?)] {
        [
            (
                label: "Claude Code",
                content: "$ claude mcp add --transport stdio clipboard -- \(helperPath)",
                note: nil
            ),
            (
                label: "Codex",
                content: "$ codex mcp add clipboard -- \(helperPath)",
                note: nil
            ),
            (
                label: "Claude Desktop",
                content: """
                {
                  "mcpServers": {
                    "clipboard": {
                      "command": "\(helperPath)"
                    }
                  }
                }
                """,
                note: "~/Library/Application Support/Claude/claude_desktop_config.json"
            ),
        ]
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Const.space24) {
                headerInstallCard
                if isEnabled {
                    toolsSection
                }
                Spacer(minLength: 0)
            }
            .padding([.horizontal, .bottom], Const.space24)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }

    // MARK: - Header + Install Card

    @ViewBuilder private var headerInstallCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Const.space12) {
                VStack(alignment: .leading, spacing: Const.space4) {
                    HStack(spacing: Const.space8) {
                        Text("MCP")
                            .font(.headline)
                        StatusBadge(
                            label: isEnabled
                                ? String(localized: "mcpRunning", table: "Localizable")
                                : String(localized: "mcpStopped", table: "Localizable"),
                            color: isEnabled ? .green : .secondary
                        )
                    }
                    Text(isEnabled
                         ? "stdio · @clipboard/mcp · \(enabledTools.count) tools exposed"
                         : "server stopped · 0 tools exposed")
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

            if isEnabled {
                Divider()

                VStack(alignment: .leading, spacing: Const.space12) {
                    HStack(spacing: Const.space12) {
                        Text(String(localized: "mcpAddTo", table: "Localizable"))
                            .font(.subheadline)

                        clientTabBar
                    }

                    let client = clients[selectedClientIndex]
                    commandBlock(client: client)

                    if let note = client.note {
                        HStack(spacing: Const.space4) {
                            Text(.mcpClaudeDesktopConfigPath)
                            Text(note)
                                .textSelection(.enabled)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(Const.space16)
            }
        }
        .settingsStyle()
    }

    @ViewBuilder private var clientTabBar: some View {
        HStack(spacing: Const.space2) {
            ForEach(Array(clients.enumerated()), id: \.offset) { index, client in
                Button {
                    selectedClientIndex = index
                } label: {
                    Text(client.label)
                        .font(.subheadline)
                        .foregroundStyle(selectedClientIndex == index ? .primary : .secondary)
                        .padding(.horizontal, Const.space10)
                        .padding(.vertical, Const.space6)
                        .background(
                            selectedClientIndex == index
                                ? Color(nsColor: .controlBackgroundColor)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: Const.settingsRadius)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Const.space4)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private func commandBlock(client: (label: String, content: String, note: String?)) -> some View {
        ZStack(alignment: .topTrailing) {
            Text(client.content)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Const.space12)
                .padding(.vertical, Const.space12)
                .padding(.trailing, Const.space32)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.06)))

            let isCopied = copiedKey == client.label
            Button {
                let raw = client.content.hasPrefix("$ ")
                    ? String(client.content.dropFirst(2))
                    : client.content
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(raw, forType: .string)
                copiedKey = client.label
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if copiedKey == client.label { copiedKey = nil }
                }
            } label: {
                Image(systemName: isCopied ? "checkmark.circle" : "doc.on.doc")
                    .font(.callout)
                    .foregroundStyle(isCopied ? Color.accentColor : .secondary)
                    .frame(width: Const.space32, height: Const.space32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: isCopied)
        }
    }

    // MARK: - Exposed Tools Section

    @ViewBuilder private var toolsSection: some View {
        VStack(alignment: .leading, spacing: Const.space12) {
            Text(String(localized: "mcpExposedTools", table: "Localizable"))
                .font(.subheadline.bold())

            VStack(spacing: 0) {
                ForEach(Array(MCPToolInfo.all.enumerated()), id: \.element.id) { index, tool in
                    if index > 0 {
                        Divider().padding(.leading, 52)
                    }
                    MCPToolRow(
                        tool: tool,
                        mcpEnabled: isEnabled,
                        isToolEnabled: enabledTools.contains(tool.name)
                    ) { enabled in
                        if enabled { enabledTools.insert(tool.name) }
                        else { enabledTools.remove(tool.name) }
                        MCPDisabledTools.save(Set(MCPToolInfo.all.map(\.name)).subtracting(enabledTools))
                    }
                }
            }
            .settingsStyle()
        }
    }
}

// MARK: - MCPToolRow

private struct MCPToolRow: View {
    let tool: MCPToolInfo
    let mcpEnabled: Bool
    let isToolEnabled: Bool
    let onToggle: (Bool) -> Void

    private var showConnected: Bool { mcpEnabled && isToolEnabled }

    var body: some View {
        HStack(spacing: Const.space12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isToolEnabled ? tool.color.opacity(0.12) : Color.secondary.opacity(0.1))
                    .frame(width: 28, height: 28)
                Image(systemName: tool.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isToolEnabled ? tool.color : Color.secondary)
            }
            .animation(.easeInOut(duration: 0.2), value: isToolEnabled)

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.system(size: 12, design: .monospaced).bold())
                    .foregroundStyle(.primary)
                Text(tool.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(tool.description)
            }

            Spacer()

            StatusBadge(
                label: showConnected ? String(localized: .mcpToolEnabled) : String(localized: .mcpToolDisabled),
                color: showConnected ? .green : .secondary
            )
            Toggle("", isOn: Binding(get: { isToolEnabled }, set: { onToggle($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
        }
        .padding(.horizontal, Const.space16)
        .padding(.vertical, Const.space10)
    }
}

// MARK: - StatusBadge

private struct StatusBadge: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: Const.space4) {
            Circle()
                .fill(color)
                .frame(width: Const.space6, height: Const.space6)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, Const.space8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
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
