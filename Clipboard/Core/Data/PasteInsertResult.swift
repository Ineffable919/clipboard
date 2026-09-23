nonisolated struct PasteInsertResult: Sendable {
    let id: Int64
    let group: Int?
    let appID: Int64?

    static let failed = PasteInsertResult(id: -1, group: nil, appID: nil)
}
