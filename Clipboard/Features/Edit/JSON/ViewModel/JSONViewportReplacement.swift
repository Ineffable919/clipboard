import Foundation

struct JSONViewportReplacement {
    let range: NSRange
    let entireDocument: Bool
    let index: JSONFoldIndex.Document?
    let prepared: JSONPreparedText?
    let previousText: String
    let previousValidity: Bool?
    let validity: Bool?
    let registeringUndo: Bool
}
