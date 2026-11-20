//
//  MCPExtensionBuilder.swift
//  Clipboard
//
//  Created by crown on 2026/11/19
//

import AppKit

// MARK: - MCPExtensionBuilder

/// 生成 Claude Desktop 的 .mcpb 扩展：内置 Node 代理把 stdio 转发到本机 HTTP 端点
nonisolated enum MCPExtensionBuilder {
    static let bundleID = "com.anthropic.claudefordesktop"

    /// 打包并返回 .mcpb 路径，端点和令牌直接写入扩展环境变量
    static func build(endpoint: String) async throws -> URL {
        let fileManager = FileManager.default
        removeStale()
        let root = fileManager.temporaryDirectory.appending(path: "clipboard-mcpb-\(UUID().uuidString)")
        let source = root.appending(path: "src")
        try fileManager.createDirectory(
            at: source.appending(path: "server"),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let icon = iconPNG()
        try manifest(endpoint: endpoint, iconPNG: icon)
            .write(to: source.appending(path: "manifest.json"), atomically: true, encoding: .utf8)
        if let icon {
            try icon.write(to: source.appending(path: "icon.png"))
        }
        try proxyScript.write(
            to: source.appending(path: "server/index.js"),
            atomically: true,
            encoding: .utf8
        )

        let output = root.appending(path: "Clipboard.mcpb")
        do {
            try await zip(source, to: output)
        } catch {
            try? fileManager.removeItem(at: root)
            throw error
        }
        try? fileManager.removeItem(at: source)
        return output
    }

    /// 安装可能在打开后很久才确认，故不定时删除，下次生成时清理旧文件（系统也会定期清理临时目录）
    private static func removeStale() {
        let fileManager = FileManager.default
        let temp = fileManager.temporaryDirectory
        let items = (try? fileManager.contentsOfDirectory(atPath: temp.path)) ?? []
        for name in items where name.hasPrefix("clipboard-mcpb-") {
            try? fileManager.removeItem(at: temp.appending(path: name))
        }
    }

    private static func manifest(endpoint: String, iconPNG: Data?) throws -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        var manifest: [String: Any] = [
            "manifest_version": "0.2",
            "name": "clipboard",
            "display_name": "Clipboard",
            "version": version,
            "description": "Read and manage your Clipboard app history.",
            "author": ["name": "Clipboard"],
            "server": [
                "type": "node",
                "entry_point": "server/index.js",
                "mcp_config": [
                    "command": "node",
                    "args": ["${__dirname}/server/index.js"],
                    "env": ["CLIPBOARD_MCP_URL": endpoint]
                ]
            ],
            "compatibility": ["platforms": ["darwin"]]
        ]
        if iconPNG != nil { manifest["icon"] = "icon.png" }
        let data = try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        return (String(bytes: data, encoding: .utf8) ?? "")
    }

    /// 扩展图标取自 App 图标，失败时不带图标
    private static func iconPNG() -> Data? {
        let size = 512
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        // 系统 App 图标四周约 10% 透明留白，放大绘制以裁掉，避免显示偏小
        let side = CGFloat(size) / 0.8
        let inset = (CGFloat(size) - side) / 2
        icon.draw(
            in: NSRect(x: inset, y: inset, width: side, height: side),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        return rep.representation(using: .png, properties: [:])
    }

    private static func zip(_ directory: URL, to output: URL) async throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/zip")
        process.currentDirectoryURL = directory
        process.arguments = ["-qr", output.path, "."]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
        guard status == 0 else {
            let data = (try? errorPipe.fileHandleForReading.readToEnd()) ?? Data()
            throw MCPClientCLIError(message: (String(bytes: data, encoding: .utf8) ?? ""))
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: output.path)
    }

    /// 无依赖的 stdio→HTTP 转发；服务端无状态，每行 JSON-RPC 对应一次 POST
    private static let proxyScript = #"""
    const readline = require("node:readline");

    const url = process.env.CLIPBOARD_MCP_URL;

    const send = (message) => process.stdout.write(JSON.stringify(message) + "\n");

    const fail = (id, text) => {
      if (id !== undefined && id !== null) {
        send({ jsonrpc: "2.0", id, error: { code: -32603, message: text } });
      }
    };

    const payloads = (type, body) => {
      if (!type.includes("text/event-stream")) return [body];
      return body
        .split("\n")
        .filter((line) => line.startsWith("data:"))
        .map((line) => line.slice(5).trim());
    };

    const forward = async (line) => {
      let id;
      try {
        id = JSON.parse(line).id;
      } catch {
        return;
      }
      try {
        const response = await fetch(url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json, text/event-stream",
          },
          body: line,
        });
        if (response.status === 202 || response.status === 204) return;
        const body = (await response.text()).trim();
        if (!response.ok) {
          fail(id, `Clipboard MCP HTTP ${response.status}: ${body.slice(0, 200)}`);
          return;
        }
        for (const item of payloads(response.headers.get("content-type") ?? "", body)) {
          if (item) send(JSON.parse(item));
        }
      } catch (error) {
        fail(id, `Clipboard MCP unreachable: ${error.message}. Is the app running with MCP enabled?`);
      }
    };

    const pending = new Set();
    const rl = readline.createInterface({ input: process.stdin });
    rl.on("line", (line) => {
      if (!line.trim()) return;
      const task = forward(line).finally(() => pending.delete(task));
      pending.add(task);
    });
    rl.on("close", async () => {
      await Promise.all(pending);
      process.exit(0);
    });
    """#
}
