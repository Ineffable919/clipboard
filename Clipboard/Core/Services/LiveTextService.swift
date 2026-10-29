import AppKit
import ImageIO
import VisionKit

/// 复用 Live Text 分析器，提供图片文字识别和搜索高亮定位所需的分析结果
@available(macOS 27.0, *)
@MainActor
final class LiveTextService {
    static let shared = LiveTextService()
    nonisolated static var isSupported: Bool { ImageAnalyzer.isSupported }

    private let analyzer = ImageAnalyzer()

    func recognizeText(from data: Data, requestId: String, submittedAt: ContinuousClock.Instant) async -> String {
        guard let analysis = try? await analyze(data: data, requestId: requestId, submittedAt: submittedAt) else {
            return ""
        }
        return analysis.transcript
    }

    func analyze(
        data: Data, requestId: String, submittedAt: ContinuousClock.Instant = .now
    ) async throws -> ImageAnalysis {
        let started = ContinuousClock.now
        log.warn("Live Text 开始：id=\(requestId)，输入=\(data.count) bytes，排队=\(submittedAt.duration(to: started))")
        do {
            try Task.checkCancellation()
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithData(data as CFData, options),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, options)
            else { throw CocoaError(.fileReadCorruptFile) }

            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let rawOrientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
            let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up
            let analysis = try await analyzer.analyze(image, orientation: orientation, configuration: .init(.text))
            try Task.checkCancellation()
            log.warn(
                "Live Text 完成：id=\(requestId)，耗时=\(started.duration(to: .now))，"
                    + "字数=\(analysis.transcript.count)"
            )
            return analysis
        } catch {
            if Task.isCancelled || error is CancellationError {
                log.warn("Live Text 取消：id=\(requestId)，耗时=\(started.duration(to: .now))")
            } else {
                let error = error as NSError
                log.warn(
                    "Live Text 失败：id=\(requestId)，耗时=\(started.duration(to: .now))，"
                        + "错误=\(error.domain)(\(error.code))，\(error.localizedDescription)"
                )
            }
            throw error
        }
    }
}
