//
//  PasteboardModel+Markdown.swift
//  Clipboard
//
//  markdown 内容检测与渲染入口
//

import AppKit
import Foundation

extension PasteboardModel {
    var usesMarkdownPreview: Bool {
        switch type {
        case .string, .rich: isMarkdown
        default: false
        }
    }

    var markdownSource: String {
        if pasteboardType == .rtf || pasteboardType == .rtfd {
            return NSAttributedString(with: data, type: pasteboardType)?.string ?? ""
        }
        return String(data: data, encoding: .utf8) ?? attributeString.string
    }

    var isMarkdown: Bool {
        if let cachedIsMarkdown {
            return cachedIsMarkdown
        }
        let result = Self.detectMarkdown(in: markdownSource)
        cachedIsMarkdown = result
        return result
    }

    // MARK: - 检测

    /// 高置信特征：命中任意一个即判定为 markdown
    private static let strongPatterns: [Regex<AnyRegexOutput>] = [
        "(?m)^[ ]{0,3}(```|~~~)", // 围栏代码块
        "(?m)^[ ]{0,3}#{1,6}[ \t]", // ATX 标题
        "(?m)^.+\\n[ ]{0,3}(=+|-+)[ \t]*$", // Setext 标题
        "(?m)^[ ]*\\|?([ ]*:?-+:?[ ]*\\|)+[ ]*:?-*:?[ ]*$", // 表格分隔行
        "!\\[[^\\]\n]*\\]\\([^)\\s]+(?:[ \t]+\"[^\"]*\")?\\)", // 图片
        "(?m)^[ ]*[-*+][ \t]+\\[[ xX]\\][ \t]+\\S", // 任务列表
        "(?m)^[ ]*[-*+][ \t]+\\S.*\\n[ ]*[-*+][ \t]+\\S", // 多行无序列表
        "(?m)^[ ]*[0-9]+\\.[ \t]+\\S.*\\n[ ]*[0-9]+\\.[ \t]+\\S", // 多行有序列表
    ].compactMap { try? Regex($0) }

    /// 普通特征：按权重累计，避免单个低信号标记造成误判
    private static let weightedPatterns: [(pattern: Regex<AnyRegexOutput>, score: Int)] = [
        ("(?m)^[ ]*[-*+][ \t]+\\S", 2), // 无序列表
        ("(?m)^[ ]*[0-9]+\\.[ \t]+\\S", 2), // 有序列表
        ("(?m)^[ ]*>[ \t]?\\S", 2), // 引用
        ("(?m)^[ ]{0,3}([-*_])([ \t]*\\1){2,}[ \t]*$", 2), // 分割线
        ("(\\*\\*|__)[^*_\n]+(\\*\\*|__)", 1), // 粗体
        ("`[^`\n]+`", 1), // 行内代码
        ("\\[[^\\]\n]+\\]\\([^)\n]+\\)", 2), // 链接
    ].compactMap { pattern, score in
        guard let regex = try? Regex(pattern) else { return nil }
        return (regex, score)
    }

    /// 保守启发式：高置信特征直接命中；普通特征按权重累计。
    /// 目标是覆盖完整预览需要的图片、列表、标题等场景，同时避免普通文本误判。
    private static func detectMarkdown(in raw: String) -> Bool {
        let text = raw.count > 8000 ? String(raw.prefix(8000)) : raw
        guard text.contains(where: { !$0.isWhitespace }) else { return false }

        for pattern in strongPatterns where text.contains(pattern) {
            return true
        }

        var score = 0
        for (pattern, weight) in weightedPatterns where text.contains(pattern) {
            score += weight
            if score >= 3 {
                return true
            }
        }
        return false
    }
}
