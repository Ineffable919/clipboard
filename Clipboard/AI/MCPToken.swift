//
//  MCPToken.swift
//  Clipboard
//
//  Created by crown on 2026/11/18
//

import Foundation

/// MCP 访问令牌，存为 0600 文件（不用钥匙串，避免调试版反复弹授权）
nonisolated enum MCPToken {
    static let prefix = "clip"
    private static let randomLength = 24
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

    /// 供密钥遮挡识别
    static func matches(_ text: some StringProtocol) -> Bool {
        text.count == prefix.count + randomLength && text.hasPrefix(prefix)
            && text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    /// 当前令牌，不存在时生成
    static func current() -> String {
        if let saved = try? String(contentsOfFile: ClipboardPaths.mcpToken, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !saved.isEmpty
        {
            return saved
        }
        return regenerate()
    }

    /// 生成并保存新令牌，旧令牌立即失效
    @discardableResult
    static func regenerate() -> String {
        // 只用字母和数字，24 位约 142 位熵
        var generator = SystemRandomNumberGenerator()
        let random = (0..<randomLength).map { _ in alphabet[Int.random(in: alphabet.indices, using: &generator)] }
        let token = prefix + String(random)
        let path = ClipboardPaths.mcpToken
        let directory = URL(filePath: path).deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: path,
            contents: Data(token.utf8),
            attributes: [.posixPermissions: 0o600]
        )
        return token
    }

    /// 常量时间比较，防计时攻击
    static func isAuthorized(_ header: String?) -> Bool {
        guard let header else { return false }
        let parts = header.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, parts[0].caseInsensitiveCompare("Bearer") == .orderedSame else {
            return false
        }
        let given = Array(parts[1].trimmingCharacters(in: .whitespaces).utf8)
        let expected = Array(current().utf8)
        guard given.count == expected.count else { return false }
        return zip(given, expected).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
}
