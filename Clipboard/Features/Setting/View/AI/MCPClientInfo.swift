//
//  MCPClientInfo.swift
//  Clipboard
//
//  Created by crown on 2026/11/18
//

import Foundation

// MARK: - MCPClientInfo

struct MCPClientInfo: Identifiable {
    private static let maskedAuthorization = "Bearer clipxxx"

    var id: String {
        name
    }

    let name: String
    let icon: String
    let subtitle: LocalizedStringResource
    let displayCommand: String
    let footer: LocalizedStringResource?
    let configNote: String?
    /// 可由 App 直接调用客户端自带命令行完成添加
    var cli: MCPClientCLI?
    private let token: String

    var commandForCopy: String {
        displayCommand.replacing(Self.maskedAuthorization, with: "Bearer \(token)")
    }
}

// MARK: - Clients

extension MCPClientInfo {
    static func all(endpoint url: String, token: String) -> [MCPClientInfo] {
        let auth = Self.maskedAuthorization
        return [
            MCPClientInfo(
                name: "Claude Desktop",
                icon: "MCPClaudeIcon",
                subtitle: .mcpConfigSub,
                displayCommand: bridgeConfig(url: url, auth: auth),
                footer: .mcpNodeNote,
                configNote: "~/Library/Application Support/Claude/claude_desktop_config.json",
                token: token
            ),
            MCPClientInfo(
                name: "Claude Code",
                icon: "MCPClaudeIcon",
                subtitle: .mcpCliSub,
                displayCommand: claudeCodeCommand(url: url, auth: auth),
                footer: .mcpClaudeFooter,
                configNote: nil,
                token: token
            ),
            MCPClientInfo(
                name: "VS Code",
                icon: "MCPVSCodeIcon",
                subtitle: .mcpCliAddSub,
                displayCommand: vsCodeCommand(url: url, auth: auth),
                footer: nil,
                configNote: nil,
                cli: vsCodeCLI(url: url, token: token),
                token: token
            ),
            MCPClientInfo(
                name: "Codex",
                icon: "MCPCodexIcon",
                subtitle: .mcpConfigSub,
                displayCommand: codexConfig(url: url, auth: auth),
                footer: nil,
                configNote: "~/.codex/config.toml",
                token: token
            ),
            MCPClientInfo(
                name: "Cursor",
                icon: "MCPCursorIcon",
                subtitle: .mcpConfigSub,
                displayCommand: cursorConfig(url: url, auth: auth),
                footer: nil,
                configNote: "~/.cursor/mcp.json",
                token: token
            )
        ]
    }

    /// Claude Desktop 经 mcp-remote 桥接
    private static func bridgeConfig(url: String, auth: String) -> String {
        """
        {
          "mcpServers": {
            "clipboard": {
              "command": "npx",
              "args": [
                "-y", "mcp-remote",
                "\(url)",
                "--header",
                "Authorization: \(auth)"
              ]
            }
          }
        }
        """
    }

    /// 用户级作用域，任何项目里都能使用
    private static func claudeCodeCommand(url: String, auth: String) -> String {
        """
        claude mcp add \\
          --transport http \\
          --scope user \\
          clipboard \(url) \\
          --header "Authorization: \(auth)"
        """
    }

    /// Codex 的 config.toml 片段
    private static func codexConfig(url: String, auth: String) -> String {
        """
        [mcp_servers.clipboard]
        url = "\(url)"

        [mcp_servers.clipboard.http_headers]
        Authorization = "\(auth)"
        """
    }

    /// VS Code 用 `code --add-mcp` 写入用户 profile，避开平台相关的配置路径
    private static func vsCodeCommand(url: String, auth: String) -> String {
        """
        code --add-mcp '{
          "name": "clipboard",
          "type": "http",
          "url": "\(url)",
          "headers": {
            "Authorization": "\(auth)"
          }
        }'
        """
    }

    /// 正式版优先，其次 Insiders；参数直接传给进程，无需 shell 转义
    private static func vsCodeCLI(url: String, token: String) -> MCPClientCLI? {
        let config: [String: Any] = [
            "name": "clipboard",
            "type": "http",
            "url": url,
            "headers": ["Authorization": "Bearer \(token)"]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: config),
            let json = String(bytes: data, encoding: .utf8)
        else { return nil }
        return MCPClientCLI(
            bundleIDs: ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"],
            path: "Contents/Resources/app/bin/code",
            arguments: ["--add-mcp", json]
        )
    }

    /// Cursor 的 mcp.json 片段
    private static func cursorConfig(url: String, auth: String) -> String {
        """
        {
          "mcpServers": {
            "clipboard": {
              "url": "\(url)",
              "headers": {
                "Authorization": "\(auth)"
              }
            }
          }
        }
        """
    }
}
