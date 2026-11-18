//
//  MCPSecretMasker.swift
//  Clipboard
//
//  Created by crown on 2026/11/17
//

import Foundation

/// 在搜索摘要中遮挡疑似密钥，避免 AI 浏览列表时把密钥带进上下文；read_item 仍返回原文
nonisolated enum MCPSecretMasker {
    /// 对应 `PasteUserDefaults.mcpMaskSecrets`，默认开启
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: PrefKey.mcpMaskSecrets.rawValue) as? Bool ?? true
    }

    /// 常见服务的密钥前缀
    private static let knownPrefixes = [
        "sk-", "sk_live_", "sk_test_", "rk_live_", "pk_live_",
        "ghp_", "gho_", "ghu_", "ghs_", "ghr_", "github_pat_", "glpat-",
        "xoxb-", "xoxp-", "xoxa-", "xapp-",
        "AKIA", "ASIA", "AIza", "ya29.", "hf_", "npm_"
    ]

    /// 无空白的长串候选；不含 `/` 与 `:`，URL 会在此处断开，避免把普通路径当成密钥
    /// Regex 不是 Sendable，不能做静态常量，按次构建（开销很小）
    private static var candidate: Regex<Substring> {
        /[A-Za-z0-9_\-+=.]{16,}/
    }

    private static var jwt: Regex<Substring> {
        /^eyJ[A-Za-z0-9_\-]+\.eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+$/
    }

    /// 返回遮挡后的文本；没有疑似密钥时返回 nil
    static func mask(_ text: String) -> String? {
        if text.contains("PRIVATE KEY-----") {
            return "[redacted private key]"
        }
        var masked = ""
        var cursor = text.startIndex
        var found = false
        for match in text.matches(of: candidate) {
            let token = String(match.output)
            guard isSecret(token) else { continue }
            found = true
            let keep = knownPrefixes.contains { token.hasPrefix($0) } ? 10 : 4
            masked += text[cursor..<match.range.lowerBound]
            masked += "\(token.prefix(keep))…[redacted, \(token.count) chars]"
            cursor = match.range.upperBound
        }
        guard found else { return nil }
        return masked + text[cursor...]
    }

    private static func isSecret(_ token: String) -> Bool {
        if token.wholeMatch(of: jwt) != nil || MCPToken.matches(token) {
            return true
        }
        if token.count >= 20, knownPrefixes.contains(where: { token.hasPrefix($0) }) {
            return true
        }
        // 通用规则：足够长且大小写字母与数字混排的随机串；纯小写十六进制（哈希、UUID）不计入
        guard token.count >= 32, !token.contains(".") else { return false }
        return token.contains(where: \.isUppercase)
            && token.contains(where: \.isLowercase)
            && token.contains(where: \.isNumber)
    }
}
