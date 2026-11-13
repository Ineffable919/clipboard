//
//  TextStatisticsWorker.swift
//  Clipboard
//
//  Created by crown on 2026/10/6
//

actor TextStatisticsWorker {
    static let shared = TextStatisticsWorker()

    func count(_ text: String, lineCount: Int?) -> TextStatistics? {
        guard !Task.isCancelled else { return nil }
        return TextStatistics(from: text, lineCount: lineCount)
    }
}
