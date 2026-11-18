//
//  AISettingsView.swift
//  Clipboard
//
//  Created by crown on 2026/6/2
//

import SwiftUI

// MARK: - AISettingsView

struct AISettingsView: View {
    @State private var isEnabled: Bool
    @State private var selectedClient: MCPClientInfo?
    private let server: MCPServer

    init(
        initialEnabled: Bool = MCPEnableFlag.isEnabled,
        server: MCPServer = .shared
    ) {
        self.server = server
        _isEnabled = State(initialValue: initialEnabled)
    }

    private var clients: [MCPClientInfo] {
        MCPClientInfo.all(endpoint: server.endpoint, token: server.token)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Const.space20) {
                MCPHeaderCard(
                    isEnabled: $isEnabled,
                    server: server
                )
                if isEnabled {
                    MCPSensitiveDataSection()

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
            .padding([.horizontal, .bottom], Const.space20)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .sheet(item: $selectedClient) { client in
            MCPClientDetailSheet(client: client)
        }
    }
}

// MARK: - MCPClientDetailSheet

private struct MCPClientDetailSheet: View {
    static let width: CGFloat = 440

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

            MCPCommandBlock(client: client)
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

                Button(client.configNote == nil ? .mcpGoToTerminal : .mcpGoPaste) {
                    Task { await openDestination() }
                }
                .buttonStyle(.borderedProminent)
            }
            .focusEffectDisabled()
        }
        .padding(Const.space24)
        .frame(width: Self.width)
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

    private func openDestination() async {
        let workspace = NSWorkspace.shared
        if let path = client.configNote {
            let url = URL(filePath: (path as NSString).expandingTildeInPath)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else { return }

            NSPasteboard.copy(client.commandForCopy)
            workspace.activateFileViewerSelecting([url])
        } else {
            NSPasteboard.copy(client.commandForCopy)
            guard let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
            _ = try? await workspace.openApplication(at: url, configuration: .init())
        }
    }
}

// MARK: - MCPCommandBlock

/// 可一键复制的等宽命令/配置块
private struct MCPCommandBlock: View {
    let client: MCPClientInfo

    var body: some View {
        Text(client.displayCommand)
            .font(.callout.monospaced())
            .lineSpacing(3)
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
            NSPasteboard.copy(client.commandForCopy)
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
    let clients = MCPClientInfo.all(
        endpoint: "http://127.0.0.1:38417/mcp",
        token: "clip0123456789abcdefghijklmn"
    )
    VStack(spacing: Const.space16) {
        ForEach(clients.filter { $0.name == "Claude Code" || $0.name == "Cursor" }) { client in
            MCPCommandBlock(client: client)
        }
    }
    .padding(Const.space24)
    .frame(width: MCPClientDetailSheet.width)
}
