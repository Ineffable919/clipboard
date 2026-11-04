//
//  OCRRequest.swift
//  Clipboard
//
//  Created by crown on 2026/10/22
//

import Foundation
import os
import Vision

/// 每次识别独立持有 Vision 请求
/// 跨线程操作仅限 Vision 的取消接口
nonisolated final class OCRRequest: @unchecked Sendable {
    private let request: VNRecognizeTextRequest
    private let cancelled = OSAllocatedUnfairLock(initialState: false)

    var isCancelled: Bool {
        cancelled.withLock { $0 }
    }

    init() {
        request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = false
    }

    func cancel() {
        cancelled.withLock { $0 = true }
        request.cancel()
    }

    func perform(data: Data, keyword: String?) throws -> [OCRTextRegion] {
        try checkCancellation()
        return try autoreleasepool {
            let handler = VNImageRequestHandler(data: data, options: [:])
            try checkCancellation()
            try handler.perform([request])
            try checkCancellation()
            var regions: [OCRTextRegion] = []
            for observation in request.results ?? [] {
                try checkCancellation()
                guard let candidate = observation.topCandidates(1).first else { continue }
                let text = candidate.string
                guard let keyword else {
                    regions.append(OCRTextRegion(text: text, boundingBox: observation.boundingBox))
                    continue
                }
                let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
                var start = text.startIndex
                while start < text.endIndex,
                      let range = text.range(
                          of: keyword, options: options, range: start..<text.endIndex, locale: .current
                      ) {
                    try checkCancellation()
                    if let box = try candidate.boundingBox(for: range)?.boundingBox {
                        regions.append(OCRTextRegion(text: String(text[range]), boundingBox: box))
                    }
                    start = range.upperBound
                }
            }
            return regions
        }
    }

    private func checkCancellation() throws {
        if isCancelled { throw CancellationError() }
    }
}
