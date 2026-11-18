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
                displayCommand: """
                    claude mcp add \\
                      --transport http \\
                      clipboard \(url) \\
                      --header "Authorization: \(auth)"
                    """,
                footer: .mcpClaudeFooter,
                configNote: nil,
                token: token
            ),
            MCPClientInfo(
                name: "VS Code",
                icon: "MCPVSCodeIcon",
                subtitle: .mcpConfigSub,
                displayCommand: urlConfig(root: "servers", url: url, auth: auth, type: "http"),
                footer: nil,
                configNote: "~/.vscode/mcp.json",
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
                displayCommand: urlConfig(root: "mcpServers", url: url, auth: auth, type: nil),
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

    /// Codex 的 config.toml 片段
    private static func codexConfig(url: String, auth: String) -> String {
        """
        [mcp_servers.clipboard]
        url = "\(url)"

        [mcp_servers.clipboard.http_headers]
        Authorization = "\(auth)"
        """
    }

    /// Cursor、VS Code
    private static func urlConfig(root: String, url: String, auth: String, type: String?) -> String {
        let typeLine = type.map { "\n      \"type\": \"\($0)\"," } ?? ""
        return """
            {
              "\(root)": {
                "clipboard": {\(typeLine)
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
