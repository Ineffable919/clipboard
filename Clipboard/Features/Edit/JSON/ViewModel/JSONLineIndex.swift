//
//  JSONLineIndex.swift
//  Clipboard
//

import Foundation

final class JSONLineIndex {
    private var starts = [0]
    private var deferredShiftStartIndex: Int?
    private var deferredShiftDelta = 0

    var lineCount: Int {
        starts.count
    }

    func replace(with newStarts: [Int]) {
        starts = newStarts.isEmpty ? [0] : newStarts
        deferredShiftStartIndex = nil
        deferredShiftDelta = 0
    }

    func applyReplacement(range: NSRange, replacement: String) {
        let replacementLength = replacement.utf16.count
        let delta = replacementLength - range.length
        let removedEnd = range.location + range.length
        let insertionIndex = upperBound(for: range.location)
        let removalEndIndex = upperBound(for: removedEnd)
        let inserted = Self.relativeStarts(in: replacement).dropFirst().map {
            range.location + $0
        }

        let removedCount = removalEndIndex - insertionIndex
        let preservesLineBreaks = removedCount == inserted.count
            && inserted.enumerated().allSatisfy { offset, newStart in
                newStart == start(at: insertionIndex + offset) + delta
            }
        if preservesLineBreaks {
            deferShift(from: insertionIndex, by: delta)
            return
        }

        materializeDeferredShift()
        if insertionIndex < removalEndIndex {
            starts.removeSubrange(insertionIndex ..< removalEndIndex)
        }

        if delta != 0, insertionIndex < starts.count {
            for index in insertionIndex ..< starts.count {
                starts[index] += delta
            }
        }

        if !inserted.isEmpty {
            starts.insert(contentsOf: inserted, at: insertionIndex)
        }
    }

    func lineAndColumn(at location: Int) -> (line: Int, column: Int) {
        let index = lineIndex(at: location)
        return (index + 1, max(0, location - start(at: index)) + 1)
    }

    func lineNumber(at location: Int) -> Int {
        lineIndex(at: location) + 1
    }

    func isLineStart(_ location: Int) -> Bool {
        let index = lowerBound(for: location)
        return index < starts.count && start(at: index) == location
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
            if start(at: middle) < value {
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
            if start(at: middle) <= value {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func start(at index: Int) -> Int {
        guard let deferredShiftStartIndex,
              index >= deferredShiftStartIndex
        else { return starts[index] }

        return starts[index] + deferredShiftDelta
    }

    private func deferShift(from index: Int, by delta: Int) {
        guard delta != 0, index < starts.count else { return }

        if deferredShiftStartIndex == index {
            deferredShiftDelta += delta
            if deferredShiftDelta == 0 {
                deferredShiftStartIndex = nil
            }
            return
        }

        materializeDeferredShift()
        deferredShiftStartIndex = index
        deferredShiftDelta = delta
    }

    private func materializeDeferredShift() {
        guard let deferredShiftStartIndex,
              deferredShiftDelta != 0
        else {
            deferredShiftStartIndex = nil
            deferredShiftDelta = 0
            return
        }

        for index in deferredShiftStartIndex ..< starts.count {
            starts[index] += deferredShiftDelta
        }
        self.deferredShiftStartIndex = nil
        deferredShiftDelta = 0
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
