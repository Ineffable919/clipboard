//
//  EditWindowState.swift
//  Clipboard
//
//  Created by crown on 2025/12/28.
//

import AppKit
import SwiftUI

struct TextStatistics: Equatable {
    let characterCount: Int
    let wordCount: Int
    let lineCount: Int

    init(from text: String) {
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
        "\(characterCount) 个字符 · \(wordCount) 单词 · \(lineCount) 行"
    }
}

@Observable
@MainActor
final class EditWindowState {
    let originalModel: PasteboardModel

    private let originalAttributedString: NSAttributedString

    private var statisticsTask: Task<Void, Never>?
    private var lastStatisticsText: String = ""

    var editedContent: NSAttributedString {
        didSet {
            scheduleStatisticsUpdate()
        }
    }

    private(set) var statistics: TextStatistics

    var hasUnsavedChanges: Bool {
        editedContent.string != originalAttributedString.string
    }

    init(model: PasteboardModel) {
        originalModel = model

        let fullAttr: NSAttributedString = if let attr = NSAttributedString(
            with: model.data,
            type: model.pasteboardType
        ) {
            attr
        } else {
            NSAttributedString(
                string: String(data: model.data, encoding: .utf8) ?? ""
            )
        }

        let cleanedAttr = Self.removeColorAttributes(from: fullAttr)

        originalAttributedString = cleanedAttr
        editedContent = cleanedAttr
        let text = cleanedAttr.string
        statistics = TextStatistics(from: text)
        lastStatisticsText = text
    }

    /// 移除字体色和背景色属性
    private static func removeColorAttributes(from attributedString: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.removeAttribute(.foregroundColor, range: fullRange)
        mutable.removeAttribute(.backgroundColor, range: fullRange)

        return mutable
    }

    private func scheduleStatisticsUpdate() {
        let currentText = editedContent.string
        guard currentText != lastStatisticsText else { return }

        statisticsTask?.cancel()
        statisticsTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let text = currentText
            let stats = await Task.detached(priority: .utility) {
                await TextStatistics(from: text)
            }.value

            guard !Task.isCancelled else { return }
            self.lastStatisticsText = text
            self.statistics = stats
        }
    }
}
