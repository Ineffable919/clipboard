//
//  OCRViewService.swift
//  Clipboard
//
//  Created by crown on 2026/01/01
//

import Foundation
import Vision

/// OCR 识别到的单个文本区域（Vision 坐标系）
nonisolated struct OCRTextRegion: Sendable {
    let text: String
    let boundingBox: CGRect
}

/// 全文 Vision OCR 在 actor 内执行，高亮请求独立并发
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

    nonisolated func recognizeHighlightRegions(
        from data: Data, keyword: String,
        requestId: String = UUID().uuidString,
        submittedAt: ContinuousClock.Instant = .now
    ) async -> [OCRTextRegion]? {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return await recognize(data: data, keyword: trimmed, requestId: requestId, submittedAt: submittedAt)
    }

    private nonisolated(nonsending) func recognize(
        data: Data, keyword: String?, requestId: String, submittedAt: ContinuousClock.Instant
    ) async -> [OCRTextRegion]? {
        let request = OCRRequest()
        return await withTaskCancellationHandler {
            if keyword != nil {
                return await withCheckedContinuation { continuation in
                    // Vision 的同步调用可能阻塞，使用独立线程避免占满 Swift 的任务线程池
                    let worker = Thread {
                        continuation.resume(returning: self.perform(
                            request, data: data, keyword: keyword, requestId: requestId, submittedAt: submittedAt
                        ))
                    }
                    worker.qualityOfService = .userInitiated
                    worker.start()
                }
            }
            return perform(request, data: data, keyword: nil, requestId: requestId, submittedAt: submittedAt)
        } onCancel: {
            request.cancel()
        }
    }

    private nonisolated func perform(
        _ request: OCRRequest, data: Data, keyword: String?, requestId: String, submittedAt: ContinuousClock.Instant
    ) -> [OCRTextRegion]? {
        let scheduled = submittedAt.duration(to: .now)
        guard !request.isCancelled else {
            log.info("OCR 开始前取消：id=\(requestId)，等待=\(scheduled)")
            return nil
        }
        let started = ContinuousClock.now
        let kind = keyword == nil ? "全文" : "高亮"
        log.info("OCR 开始：id=\(requestId)，类型=\(kind)，输入=\(data.count) bytes，等待=\(scheduled)")
        do {
            let regions = try request.perform(data: data, keyword: keyword)
            log.info("OCR 完成：id=\(requestId)，类型=\(kind)，耗时=\(started.duration(to: .now))，区域数=\(regions.count)")
            return regions
        } catch {
            let elapsed = started.duration(to: .now)
            if request.isCancelled || error is CancellationError {
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
