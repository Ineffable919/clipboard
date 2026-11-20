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

/// Vision 识别统一在独立线程执行；全文识别串行，高亮请求独立并发
actor OCRViewService {
    static let shared = OCRViewService()

    private var fullTextTail: Task<[OCRTextRegion]?, Never>?

    func recognizeText(
        from data: Data,
        requestId: String = UUID().uuidString,
        submittedAt: ContinuousClock.Instant = .now
    ) async -> String {
        // 串行排队，连续入库多张图片时一次只识别一张
        let previous = fullTextTail
        let task = Task {
            _ = await previous?.value
            return await recognize(
                data: data, keyword: nil, qos: .utility, requestId: requestId, submittedAt: submittedAt
            )
        }
        fullTextTail = task
        let regions = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        return regions?.map(\.text).joined(separator: "\n") ?? ""
    }

    nonisolated func recognizeHighlightRegions(
        from data: Data, keyword: String,
        requestId: String = UUID().uuidString,
        submittedAt: ContinuousClock.Instant = .now
    ) async -> [OCRTextRegion]? {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return await recognize(
            data: data, keyword: trimmed, qos: .userInitiated, requestId: requestId, submittedAt: submittedAt
        )
    }

    private nonisolated func recognize(
        data: Data, keyword: String?, qos: QualityOfService, requestId: String, submittedAt: ContinuousClock.Instant
    ) async -> [OCRTextRegion]? {
        let request = OCRRequest()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Vision 同步调用耗时且可能阻塞，使用独立线程避免占用 Swift 并发线程池
                let worker = Thread {
                    continuation.resume(
                        returning: self.perform(
                            request, data: data, keyword: keyword, requestId: requestId, submittedAt: submittedAt
                        ))
                }
                worker.qualityOfService = qos
                worker.start()
            }
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
