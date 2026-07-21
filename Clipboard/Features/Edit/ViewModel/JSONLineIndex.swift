//
//  JSONLineIndex.swift
//  Clipboard
//

import Foundation

final class JSONLineIndex {
    private(set) var starts = [0]

    var lineCount: Int {
        starts.count
    }

    func replace(with newStarts: [Int]) {
        starts = newStarts.isEmpty ? [0] : newStarts
    }

    func applyReplacement(range: NSRange, replacement: String) {
        let replacementLength = replacement.utf16.count
        let delta = replacementLength - range.length
        let removedEnd = range.location + range.length

        starts.removeAll { start in
            start > range.location && start <= removedEnd
        }

        if delta != 0 {
            for index in starts.indices where starts[index] > removedEnd {
                starts[index] += delta
            }
        }

        let inserted = Self.relativeStarts(in: replacement).dropFirst().map {
            range.location + $0
        }
        starts.append(contentsOf: inserted)
        starts.sort()

        var previous: Int?
        starts.removeAll { value in
            defer { previous = value }
            return previous == value
        }
    }

    func lineAndColumn(at location: Int) -> (line: Int, column: Int) {
        let index = lineIndex(at: location)
        return (index + 1, max(0, location - starts[index]) + 1)
    }

    func lineNumber(at location: Int) -> Int {
        lineIndex(at: location) + 1
    }

    func isLineStart(_ location: Int) -> Bool {
        let index = lowerBound(for: location)
        return index < starts.count && starts[index] == location
    }

    nonisolated static func build(for text: String) -> [Int] {
        relativeStarts(in: text)
    }

    private func lineIndex(at location: Int) -> Int {
        max(0, upperBound(for: location) - 1)
    }

    private func lowerBound(for value: Int) -> Int {
        var lower = 0
        var upper = starts.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if starts[middle] < value {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func upperBound(for value: Int) -> Int {
        var lower = 0
        var upper = starts.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if starts[middle] <= value {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private nonisolated static func relativeStarts(in text: String) -> [Int] {
        var result = [0]
        result.reserveCapacity(max(1, text.utf16.count / 40))
        var offset = 0
        var pendingCarriageReturn = false

        for codeUnit in text.utf16 {
            if offset.isMultiple(of: 16384),
               withUnsafeCurrentTask(body: { $0?.isCancelled ?? false })
            {
                return [0]
            }
            if pendingCarriageReturn {
                if codeUnit == 0x0A {
                    result.append(offset + 1)
                    pendingCarriageReturn = false
                    offset += 1
                    continue
                }
                result.append(offset)
                pendingCarriageReturn = false
            }

            if codeUnit == 0x0D {
                pendingCarriageReturn = true
            } else if codeUnit == 0x0A {
                result.append(offset + 1)
            }
            offset += 1
        }

        if pendingCarriageReturn {
            result.append(offset)
        }

        return result
    }
}
