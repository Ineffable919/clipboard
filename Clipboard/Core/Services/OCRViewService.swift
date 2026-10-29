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

/// macOS 27 使用 Live Text，旧版 Vision 同一时间只执行一次识别
actor OCRViewService {
    static let shared = OCRViewService()

    func recognizeText(
        from data: Data,
        requestId: String = UUID().uuidString,
        submittedAt: ContinuousClock.Instant = .now
    ) async -> String {
        if #available(macOS 27.0, *), LiveTextService.isSupported {
            return await LiveTextService.shared.recognizeText(
                from: data, requestId: requestId, submittedAt: submittedAt
            )
        }
        guard let regions = await recognize(
            data: data, keyword: nil, requestId: requestId, submittedAt: submittedAt
        ) else { return "" }
        return regions.map(\.text).joined(separator: "\n")
    }

    func recognizeHighlightRegions(
        from data: Data, keyword: String,
        requestId: String = UUID().uuidString,
        submittedAt: ContinuousClock.Instant = .now
    ) async -> [OCRTextRegion]? {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return await recognize(data: data, keyword: trimmed, requestId: requestId, submittedAt: submittedAt)
    }

    private func recognize(
        data: Data, keyword: String?, requestId: String, submittedAt: ContinuousClock.Instant
    ) async -> [OCRTextRegion]? {
        let queued = submittedAt.duration(to: .now)
        guard !Task.isCancelled else {
            log.warn("OCR 排队期间取消：id=\(requestId)，等待=\(queued)")
            return nil
        }
        let started = ContinuousClock.now
        let kind = keyword == nil ? "全文" : "高亮"
        log.warn("OCR 开始：id=\(requestId)，类型=\(kind)，输入=\(data.count) bytes，排队=\(queued)")
        let request = OCRRequest()
        do {
            let regions = try await withTaskCancellationHandler {
                try request.perform(data: data, keyword: keyword)
            } onCancel: {
                request.cancel()
            }
            log.warn("OCR 完成：id=\(requestId)，类型=\(kind)，耗时=\(started.duration(to: .now))，区域数=\(regions.count)")
            return regions
        } catch {
            let elapsed = started.duration(to: .now)
            if Task.isCancelled || error is CancellationError {
                log.warn("OCR 取消：id=\(requestId)，类型=\(kind)，耗时=\(elapsed)")
            } else {
                let error = error as NSError
                log.warn(
                    "OCR 失败：id=\(requestId)，类型=\(kind)，耗时=\(elapsed)，错误=\(error.domain)(\(error.code))，"
                        + error.localizedDescription
                )
            }
            return nil
        }
    }
}
