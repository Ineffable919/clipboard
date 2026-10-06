actor TextStatisticsWorker {
    static let shared = TextStatisticsWorker()

    func count(_ text: String, lineCount: Int?) -> TextStatistics? {
        guard !Task.isCancelled else { return nil }
        return TextStatistics(from: text, lineCount: lineCount)
    }
}
