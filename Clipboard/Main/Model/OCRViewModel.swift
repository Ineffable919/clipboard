//
//  OCRViewModel.swift
//  Clipboard
//
//  Created by crown on 2026/01/01.
//

import AppKit
import Vision

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
            log.warn("OCR 失败: \(error.localizedDescription)")
        }
        return ""
    }
}
