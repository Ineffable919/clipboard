//
//  TextStatistics.swift
//  Clipboard
//
//  Created by crown on 2025/12/28.
//

import Foundation

/// 文本统计信息（字符数 / 词数 / 行数）
struct TextStatistics: Equatable, Sendable {
    let characterCount: Int
    let wordCount: Int
    let lineCount: Int

    nonisolated init(from text: String) {
        characterCount = text.count

        if text.isEmpty {
            wordCount = 0
            lineCount = 0
        } else {
            wordCount = text.smartWordCount
            lineCount = text.count(where: { $0.isNewline }) + 1
        }
    }

    var displayString: String {
        String(localized: .textStats(characterCount, wordCount, lineCount))
    }
}
