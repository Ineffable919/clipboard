//
//  OCRViewModel.swift
//  Clipboard
//
//  Created by crown on 2026/01/01.
//

import AppKit
import Vision

/// OCR 识别到的单个文本区域（Vision 坐标系）
struct OCRTextRegion {
    let text: String
    let boundingBox: CGRect
}

class OCRViewModel {
    static let shared = OCRViewModel()

    func recognizeText(from data: Data) async -> String {
        guard let image = NSImage(data: data),
              let cgImage = image.cgImage(
                  forProposedRect: nil,
                  context: nil,
                  hints: nil
              )
        else { return "" }

        return await Task.detached {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
                return (request.results ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
            } catch {
                return ""
            }
        }.value
    }

    /// 识别文字并返回匹配关键字的精确子串级 bounding box
    func recognizeHighlightRegions(
        from data: Data,
        keyword: String
    ) async -> [OCRTextRegion] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let image = NSImage(data: data),
              let cgImage = image.cgImage(
                  forProposedRect: nil,
                  context: nil,
                  hints: nil
              )
        else { return [] }

        return await Task.detached {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                return [OCRTextRegion]()
            }

            var regions = [OCRTextRegion]()

            for observation in request.results ?? [] {
                guard let candidate = observation.topCandidates(1).first else {
                    continue
                }

                let text = candidate.string
                let options: String.CompareOptions = [
                    .caseInsensitive,
                    .diacriticInsensitive,
                    .widthInsensitive,
                ]

                var searchStart = text.startIndex
                while searchStart < text.endIndex,
                      let range = text.range(
                          of: trimmed,
                          options: options,
                          range: searchStart ..< text.endIndex,
                          locale: .current
                      )
                {
                    // 用 VNRecognizedText 的 boundingBox(for:) 获取子串精确位置
                    if let box = try? candidate.boundingBox(
                        for: range
                    )?.boundingBox {
                        regions.append(OCRTextRegion(text: String(text[range]), boundingBox: box))
                    }
                    searchStart = range.upperBound
                }
            }

            return regions
        }.value
    }
}
