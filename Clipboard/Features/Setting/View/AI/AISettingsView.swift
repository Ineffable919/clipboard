import SwiftUI

struct AISettingsView: View {
    @State private var isEnabled = MCPEnableFlag.isEnabled
    @State private var copiedKey: String? = nil

    private var helperPath: String {
        Bundle.main.bundleURL
            .appending(path: "Contents/MacOS/clip-mcp")
            .path
    }

    private var clients: [(label: String, content: String, note: String?)] {
        [
            (
                label: "Claude Code",
                content: "claude mcp add --transport stdio clipboard -- \(helperPath)",
                note: nil
            ),
            (
                label: "Codex",
                content: "codex mcp add clipboard -- \(helperPath)",
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

                // MARK: - Toggle + description

                VStack(alignment: .leading, spacing: Const.space8) {
                    SettingToggleRow(
                        title: String(localized: .mcpEnable),
                        isOn: $isEnabled
                    )
                    .onChange(of: isEnabled) { _, newValue in
                        MCPEnableFlag.setEnabled(newValue)
                    }

                    Text(.mcpDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, Const.space4)
                }
                .padding(.horizontal, Const.space16)
                .settingsStyle()

                // MARK: - Install commands

                if isEnabled {
                    VStack(alignment: .leading, spacing: Const.space12) {
                        Text(.mcpAddToTools)
                            .font(.headline)
                            .bold()

                        VStack(spacing: 0) {
                            ForEach(Array(clients.enumerated()), id: \.offset) { index, client in
                                AIClientRow(
                                    label: client.label,
                                    content: client.content,
                                    note: client.note,
                                    copiedKey: $copiedKey
                                )
                                if index < clients.count - 1 {
                                    Divider()
                                        .padding(.leading, Const.space12)
                                }
                            }
                        }
                        .settingsStyle()
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(Const.space24)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - AIClientRow

private struct AIClientRow: View {
    let label: String
    let content: String
    let note: String?
    @Binding var copiedKey: String?

    private var isCopied: Bool { copiedKey == label }

    var body: some View {
        VStack(alignment: .leading, spacing: Const.space8) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topTrailing) {
                Text(content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Const.space10)
                    .padding(.vertical, Const.space10)
                    .padding(.trailing, Const.space24)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                    copiedKey = label
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        if copiedKey == label { copiedKey = nil }
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(isCopied ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: isCopied)
            }

            if let note {
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
        .padding(Const.space12)
    }
}

#Preview {
    AISettingsView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
