import AppKit
@preconcurrency import LinkPresentation

nonisolated enum LinkPreviewLoader {
    enum ImagePolicy {
        case previewThenIcon
        case iconOrPreview
    }

    @concurrent
    static func fetch(for url: URL, imagePolicy: ImagePolicy) async -> sending LinkPreviewMetadata {
        do {
            let metadata = try await fetchMetadata(for: url)
            try Task.checkCancellation()

            switch imagePolicy {
            case .previewThenIcon:
                let preview = await loadImage(from: metadata.imageProvider, policy: imagePolicy)
                try Task.checkCancellation()
                let icon = preview == nil ? await loadImage(from: metadata.iconProvider, policy: imagePolicy) : nil
                return LinkPreviewMetadata(title: metadata.title, previewImage: preview, iconImage: icon)
            case .iconOrPreview:
                // 按 provider 是否存在选择来源，图标解码失败时不再加载预览图
                let icon = await loadImage(from: metadata.iconProvider ?? metadata.imageProvider, policy: imagePolicy)
                return LinkPreviewMetadata(title: metadata.title, previewImage: nil, iconImage: icon)
            }
        } catch {
            return LinkPreviewMetadata(title: nil, previewImage: nil, iconImage: nil)
        }
    }

    private static func fetchMetadata(for url: URL) async throws -> LPLinkMetadata {
        let provider = LPMetadataProvider()
        provider.timeout = 5.0
        nonisolated(unsafe) let unsafeProvider = provider

        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await provider.startFetchingMetadata(for: url)
        } onCancel: {
            unsafeProvider.cancel()
        }
    }

    private static func loadImage(from provider: NSItemProvider?, policy: ImagePolicy) async -> NSImage? {
        if policy == .previewThenIcon, Task.isCancelled { return nil }
        guard let provider else { return nil }
        let progress = Progress(totalUnitCount: 1)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let load = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    continuation.resume(returning: image as? NSImage)
                }
                progress.addChild(load, withPendingUnitCount: 1)
                if Task.isCancelled { load.cancel() }
            }
        } onCancel: {
            progress.cancel()
        }
    }
}
