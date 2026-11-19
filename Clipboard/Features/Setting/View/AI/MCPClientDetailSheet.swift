//
//  MCPClientDetailSheet.swift
//  Clipboard
//
//  Created by crown on 2026/11/19
//

import SwiftUI

// MARK: - MCPClientDetailSheet

struct MCPClientDetailSheet: View {
    static let width: CGFloat = 440

    let client: MCPClientInfo
    private let destination: MCPConfigDestination
    @State private var addState: AddState = .idle
    private let server = MCPServer.shared
    @Environment(\.dismiss) private var dismiss
    @FocusState private var cancelFocused: Bool

    init(client: MCPClientInfo) {
        self.client = client
        destination = MCPConfigDestination(client: client)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            clientIcon

            Text(.mcpConnectFormat(client.name))
                .font(.title2.bold())
                .padding(.bottom, Const.space8)

            Text(client.subtitle)
                .padding(.bottom, client.installsExtension && hasDetails ? Const.space4 : Const.space16)

            if !client.installsExtension {
                MCPCommandBlock(client: client)
                    .padding(.bottom, hasDetails ? Const.space8 : Const.space16)
            }

            if hasDetails {
                VStack(alignment: .leading, spacing: Const.space8) {
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
                    }

                    if let footer = client.footer {
                        Text(footer)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let notice {
                        Label {
                            Text(notice.text)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(
                                systemName: notice.isError
                                    ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                            )
                                .foregroundStyle(notice.isError ? .orange : .green)
                        }
                    }
                }
                .padding(.bottom, Const.space16)
            }

            HStack {
                Spacer()
                if addState != .succeeded {
                    Button(.cancelButton) {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .focused($cancelFocused)
                }

                Button(primaryTitle) {
                    Task { await openDestination() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(addState == .running)
            }
            .focusEffectDisabled()
        }
        .padding(Const.space24)
        .frame(width: Self.width)
        .defaultFocus($cancelFocused, true)
    }

    private var primaryTitle: LocalizedStringResource {
        switch destination {
        case .terminal: .mcpGoToTerminal
        case .file, .folder: .mcpGoPaste
        case .missing: .mcpCopyConfig
        case .appMissing: client.installsExtension ? .close : .mcpCopyCommand
        case .cli: addState == .succeeded ? .close : .mcpAddToFormat(client.name)
        case .extensionApp: .mcpInstallExtension
        }
    }

    /// 命令块下方是否有路径、提示或说明
    private var hasDetails: Bool {
        client.configNote != nil || notice != nil || client.footer != nil
    }

    /// 命令块下方的状态提示
    private var notice: (text: LocalizedStringResource, isError: Bool)? {
        switch addState {
        case .succeeded: return (.mcpAddedFormat(client.name), false)
        case .failed(let message): return (.mcpAddFailed(message), true)
        case .idle, .running: break
        }
        switch destination {
        case .missing: return (.mcpConfigMissing(client.name), true)
        case .appMissing: return (.mcpAppMissing(client.name), true)
        default: return nil
        }
    }

    private var clientIcon: some View {
        Image(client.icon)
            .resizable()
            .scaledToFit()
            .scaleEffect(client.iconScale)
            .frame(width: 40, height: 40)
            .clipShape(.rect(cornerRadius: 8))
            .padding(.bottom, Const.space16)
    }

    private func openDestination() async {
        if case .cli(let executable) = destination {
            await add(with: executable)
            return
        }
        if case .extensionApp(let app) = destination {
            await install(extensionIn: app)
            return
        }
        if !client.installsExtension {
            NSPasteboard.copy(client.commandForCopy)
        }
        let workspace = NSWorkspace.shared
        switch destination {
        case .file(let url):
            workspace.activateFileViewerSelecting([url])
        case .folder(let url):
            workspace.open(url)
        case .missing, .appMissing:
            dismiss()
        case .terminal:
            guard let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
            _ = try? await workspace.openApplication(at: url, configuration: .init())
        case .cli, .extensionApp:
            break
        }
    }

    private func install(extensionIn app: URL) async {
        addState = .running
        do {
            let bundle = try await MCPExtensionBuilder.build(endpoint: server.endpoint, token: server.token)
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            try await NSWorkspace.shared.open([bundle], withApplicationAt: app, configuration: configuration)
            dismiss()
        } catch {
            addState = .failed(error.localizedDescription)
        }
    }

    private func add(with executable: URL) async {
        guard addState != .succeeded, let cli = client.cli else {
            dismiss()
            return
        }
        addState = .running
        do {
            try await cli.run(executable)
            addState = .succeeded
        } catch {
            addState = .failed(error.localizedDescription)
        }
    }
}

// MARK: - AddState

private enum AddState: Equatable {
    case idle
    case running
    case succeeded
    case failed(String)
}

// MARK: - MCPConfigDestination

/// 主按钮的落点：直接调用客户端命令行、打开终端，或配置文件 / 其所在目录
private enum MCPConfigDestination: Equatable {
    case cli(URL)
    /// 通过 .mcpb 扩展安装到指定 App
    case extensionApp(URL)
    /// 支持命令行添加，但客户端未安装
    case appMissing
    case terminal
    case file(URL)
    case folder(URL)
    /// 配置目录不存在：客户端未安装或从未启动
    case missing

    init(client: MCPClientInfo) {
        if client.installsExtension {
            self = NSWorkspace.shared.urlForApplication(withBundleIdentifier: MCPExtensionBuilder.bundleID)
                .map { .extensionApp($0) } ?? .appMissing
            return
        }
        if let cli = client.cli {
            self = cli.executable.map { .cli($0) } ?? .appMissing
            return
        }
        guard let path = client.configNote else {
            self = .terminal
            return
        }
        let file = URL(filePath: (path as NSString).expandingTildeInPath)
        let folder = file.deletingLastPathComponent()
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: file.path) {
            self = .file(file)
        } else if fileManager.fileExists(atPath: folder.path) {
            self = .folder(folder)
        } else {
            self = .missing
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

private func previewClient(_ name: String) -> MCPClientInfo? {
    MCPClientInfo.all(
        endpoint: "http://127.0.0.1:38417/mcp",
        token: "clip0123456789abcdefghijklmn"
    )
    .first { $0.name == name }
}

#Preview("Command block") {
    VStack(spacing: Const.space16) {
        ForEach(["Claude Code", "Cursor"], id: \.self) { name in
            if let client = previewClient(name) {
                MCPCommandBlock(client: client)
            }
        }
    }
    .padding(Const.space24)
    .frame(width: MCPClientDetailSheet.width)
}

#Preview("Claude Desktop") {
    if let client = previewClient("Claude Desktop") {
        MCPClientDetailSheet(client: client)
    }
}

#Preview("Claude Code") {
    if let client = previewClient("Claude Code") {
        MCPClientDetailSheet(client: client)
    }
}

#Preview("VS Code") {
    if let client = previewClient("VS Code") {
        MCPClientDetailSheet(client: client)
    }
}

#Preview("Codex") {
    if let client = previewClient("Codex") {
        MCPClientDetailSheet(client: client)
    }
}

#Preview("Cursor") {
    if let client = previewClient("Cursor") {
        MCPClientDetailSheet(client: client)
    }
}
