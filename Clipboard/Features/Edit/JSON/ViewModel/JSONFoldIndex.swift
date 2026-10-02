import Foundation

/// 保存跨行对象和数组的原文 UTF-16 范围
enum JSONFoldIndex {
    nonisolated struct Document: Sendable {
        let lineStarts: [Int]
        let nodes: [Node]
        let statisticsLineCount: Int
    }

    nonisolated struct Node: Sendable {
        let lineStart: Int
        let body: NSRange
    }

    private nonisolated struct Opening {
        let character: UInt8
        let location: Int
        let lineStart: Int
        let node: Int
    }

    nonisolated static func build(for text: String) -> [Node] {
        document(for: text).nodes
    }

    nonisolated static func document(for text: String) -> Document {
        var source = text
        return source.withUTF8 { bytes in
            scan(bytes)
        }
    }

    // 保持逐字节热路径在单个循环内，避免 Debug 下的每字节方法调用开销
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private nonisolated static func scan(_ bytes: UnsafeBufferPointer<UInt8>) -> Document {
        var nodes: [Node] = []
        var lineStarts = [0]
        lineStarts.reserveCapacity(bytes.count / 40)
        var offset = 0
        var stack: [Opening] = []
        var lineStart = 0
        var quoted = false
        var escaped = false
        var previousCarriageReturn = false
        var index = 0
        var extraLineBreaks = 0
        var nextCancellationCheck = 0
        while index < bytes.count {
            if index >= nextCancellationCheck {
                if Task.isCancelled {
                    return Document(lineStarts: [0], nodes: [], statisticsLineCount: 0)
                }
                nextCancellationCheck = index + 16384
            }
            let byte = bytes[index]
            if !quoted, byte == 32 || byte == 9 {
                let start = index
                repeat { index += 1 } while index < bytes.count && (bytes[index] == 32 || bytes[index] == 9)
                offset += index - start
                previousCarriageReturn = false
                continue
            }
            if quoted {
                if escaped {
                    escaped = false
                } else if byte == 92 {
                    escaped = true
                } else if byte == 34 {
                    quoted = false
                }
            } else {
                switch byte {
                case 34:
                    quoted = true
                case 123, 91:
                    stack.append(Opening(
                        character: byte,
                        location: offset,
                        lineStart: lineStart,
                        node: nodes.count
                    ))
                    nodes.append(Node(lineStart: lineStart, body: NSRange(location: offset + 1, length: 0)))
                case 125, 93:
                    if let opening = stack.popLast(),
                       (opening.character == 123 && byte == 125)
                       || (opening.character == 91 && byte == 93) {
                        if lineStart > opening.lineStart {
                            nodes[opening.node] = Node(
                                lineStart: opening.lineStart,
                                body: NSRange(location: opening.location + 1, length: offset - opening.location - 1)
                            )
                        }
                    } else {
                        stack.removeAll(keepingCapacity: true)
                    }
                default:
                    break
                }
            }
            if byte < 128 {
                offset += 1
            } else if byte >= 240 {
                offset += 2
            } else if byte >= 192 {
                offset += 1
            }
            if byte == 11 || byte == 12
                || (byte == 194 && index + 1 < bytes.count && bytes[index + 1] == 133)
                || (byte == 226 && index + 2 < bytes.count && bytes[index + 1] == 128
                    && (bytes[index + 2] == 168 || bytes[index + 2] == 169)) {
                extraLineBreaks += 1
            }
            if byte == 10 || byte == 13 {
                lineStart = offset
                if byte == 10, previousCarriageReturn {
                    lineStarts[lineStarts.count - 1] = offset
                } else {
                    lineStarts.append(offset)
                }
            }
            previousCarriageReturn = byte == 13
            index += 1
        }
        return Document(
            lineStarts: lineStarts, nodes: nodes.filter { $0.body.length > 0 },
            statisticsLineCount: bytes.isEmpty ? 0 : lineStarts.count + extraLineBreaks
        )
    }
}
