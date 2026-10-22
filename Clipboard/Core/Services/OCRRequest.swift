//
//  OCRRequest.swift
//  Clipboard
//
//  Created by crown on 2026/10/22.
//

import Foundation
import Vision

/// 配置和结果只在 OCR actor 内访问；跨线程操作仅限 Vision 的取消接口
nonisolated final class OCRRequest: @unchecked Sendable {
    private let request: VNRecognizeTextRequest

    init() {
        request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true
    }

    func cancel() {
        request.cancel()
    }

    func perform(data: Data, keyword: String?) -> [OCRTextRegion] {
        guard !Task.isCancelled else { return [] }
        return autoreleasepool {
            let handler = VNImageRequestHandler(data: data, options: [:])
            do {
                try handler.perform([request])
            } catch {
                return []
            }
            guard !Task.isCancelled else { return [] }
            var regions: [OCRTextRegion] = []
            for observation in request.results ?? [] {
                guard !Task.isCancelled else { return [] }
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
                    guard !Task.isCancelled else { return [] }
                    if let box = try? candidate.boundingBox(for: range)?.boundingBox {
                        regions.append(OCRTextRegion(text: String(text[range]), boundingBox: box))
                    }
                    start = range.upperBound
                }
            }
            return regions
        }
    }
}
