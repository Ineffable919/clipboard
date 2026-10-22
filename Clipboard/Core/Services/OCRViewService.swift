//
//  OCRViewService.swift
//  Clipboard
//
//  Created by crown on 2026/01/01.
//

import Foundation
import Vision

/// OCR 识别到的单个文本区域（Vision 坐标系）
nonisolated struct OCRTextRegion: Sendable {
    let text: String
    let boundingBox: CGRect
}

/// 同一时间只执行一次识别，排队期间取消的任务不会再解码图片
actor OCRViewService {
    static let shared = OCRViewService()

    func recognizeText(from data: Data) async -> String {
        let regions = await recognize(data: data, keyword: nil)
        return regions.map(\.text).joined(separator: "\n")
    }

    func recognizeHighlightRegions(from data: Data, keyword: String) async -> [OCRTextRegion] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return await recognize(data: data, keyword: trimmed)
    }

    private func recognize(data: Data, keyword: String?) async -> [OCRTextRegion] {
        guard !Task.isCancelled else { return [] }
        let request = OCRRequest()
        return await withTaskCancellationHandler {
            request.perform(data: data, keyword: keyword)
        } onCancel: {
            request.cancel()
        }
    }
}
