import AppKit

/// 后台生成的文档、索引和首屏排版结果
nonisolated struct JSONDocument: Sendable {
    let text: String
    let isValid: Bool
    let index: JSONFoldIndex.Document?
    let preparedText: JSONPreparedText?

    private init(_ text: String, isValid: Bool, prepare: Bool, width: CGFloat) {
        self.text = text
        self.isValid = isValid
        index = prepare && !Task.isCancelled ? JSONFoldIndex.document(for: text) : nil
        preparedText = prepare && !Task.isCancelled && text.utf8.count >= 1_048_576
            ? JSONPreparedText(text, width: width, lineStarts: index?.lineStarts) : nil
    }

    static func load(
        data: Data, type: String, width: CGFloat,
        onValidation: @MainActor @Sendable (Bool) -> Void
    ) async -> Self {
        let (text, isValid) = autoreleasepool {
            let text = EditTextLoader.load(data: data, typeRawValue: type)
            let isValid = JSONTransformer.looksLikeJSON(text) && JSONTransformer.isValid(text)
            return (text, isValid)
        }
        await onValidation(isValid)
        return autoreleasepool { Self(text, isValid: isValid, prepare: isValid, width: width) }
    }

    static func prepare(_ text: String, knownValidity: Bool? = nil, width: CGFloat) -> Self {
        autoreleasepool {
            Self(text, isValid: knownValidity ?? JSONTransformer.isValid(text), prepare: true, width: width)
        }
    }

    static func transform(
        _ source: String, action: JSONToolAction, entireDocument: Bool,
        knownValidity: Bool? = nil, width: CGFloat
    ) throws -> (document: Self, changed: Bool) {
        try autoreleasepool {
            let text = try JSONTransformer.transform(source, action: action)
            try Task.checkCancellation()
            let changed = !(source as NSString).isEqual(to: text)
            let isValid: Bool
            if !changed, let knownValidity {
                isValid = knownValidity
            } else {
                isValid = switch action {
                case .format, .compact, .sortKeys, .renameKeys: true
                case .encodeUnicode: knownValidity ?? JSONTransformer.isValid(text)
                default: JSONTransformer.isValid(text)
                }
            }
            return (
                Self(text, isValid: isValid, prepare: changed && entireDocument, width: width),
                changed
            )
        }
    }
}
