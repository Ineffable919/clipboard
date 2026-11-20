//
//  MCPClientInfo.swift
//  Clipboard
//
//  Created by crown on 2026/11/18
//

import Foundation

// MARK: - MCPClientInfo

struct MCPClientInfo: Identifiable {
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
    /// 通过 .mcpb 扩展安装（Claude Desktop）
    var installsExtension = false
    /// 素材自带留白较多时放大显示
    var iconScale: CGFloat = 1
}

// MARK: - Clients

extension MCPClientInfo {
    static func all(endpoint url: String) -> [MCPClientInfo] {
        return [
            MCPClientInfo(
                name: "Claude Desktop",
                icon: "MCPClaudeIcon",
                subtitle: .mcpExtensionSub,
                displayCommand: url,
                footer: .mcpExtensionNote,
                configNote: nil,
                installsExtension: true
            ),
            MCPClientInfo(
                name: "Claude Code",
                icon: "MCPClaudeIcon",
                subtitle: .mcpCliSub,
                displayCommand: claudeCodeCommand(url: url),
                footer: .mcpClaudeFooter,
                configNote: nil
            ),
            MCPClientInfo(
                name: "VS Code",
                icon: "MCPVSCodeIcon",
                subtitle: .mcpCliAddSub,
                displayCommand: vsCodeCommand(url: url),
                footer: nil,
                configNote: nil,
                cli: vsCodeCLI(url: url)
            ),
            MCPClientInfo(
                name: "Codex",
                icon: "MCPCodexIcon",
                subtitle: .mcpConfigSub,
                displayCommand: codexConfig(url: url),
                footer: nil,
                configNote: "~/.codex/config.toml",
                iconScale: 1.3
            ),
            MCPClientInfo(
                name: "Cursor",
                icon: "MCPCursorIcon",
                subtitle: .mcpConfigSub,
                displayCommand: cursorConfig(url: url),
                footer: nil,
                configNote: "~/.cursor/mcp.json"
            )
        ]
    }

    /// 用户级作用域，任何项目里都能使用
    private static func claudeCodeCommand(url: String) -> String {
        """
        claude mcp add --transport http --scope user clipboard \(url)
        """
    }

    /// Codex 的 config.toml 片段
    private static func codexConfig(url: String) -> String {
        """
        [mcp_servers.clipboard]
        url = "\(url)"
        """
    }

    /// VS Code 用 `code --add-mcp` 写入用户 profile，避开平台相关的配置路径
    private static func vsCodeCommand(url: String) -> String {
        """
        code --add-mcp '{
          "name": "clipboard",
          "type": "http",
          "url": "\(url)"
        }'
        """
    }

    /// 正式版优先，其次 Insiders；参数直接传给进程，无需 shell 转义
    private static func vsCodeCLI(url: String) -> MCPClientCLI? {
        let config: [String: Any] = [
            "name": "clipboard",
            "type": "http",
            "url": url
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
    private static func cursorConfig(url: String) -> String {
        """
        {
          "mcpServers": {
            "clipboard": {
              "url": "\(url)"
            }
          }
        }
        """
    }
}
