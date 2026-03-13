//
//  FloatingLinkPreviewView.swift
//  Clipboard
//
//  紧凑型链接预览，适配 Floating 模式的横向卡片布局
//

import LinkPresentation
import SwiftUI

struct FloatingLinkPreviewView: View {
    let model: PasteboardModel
    let searchKeyword: String

    @State private var title: String?
    @State private var iconImage: NSImage?

    private var url: URL? {
        model.attributeString.string.asCompleteURL()
    }

    var body: some View {
        if let url {
            HStack(spacing: Const.space8) {
                iconView
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title ?? url.host() ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Group {
                        if searchKeyword.isEmpty {
                            Text(url.absoluteString)
                        } else {
                            Text(model.highlightedPlainText(keyword: searchKeyword))
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
            }
            .task {
                await loadMetadata(for: url)
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconImage {
            Image(nsImage: iconImage)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: 4))
        } else {
            Image(systemName: "link")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.1))
                .clipShape(.rect(cornerRadius: 4))
        }
    }

    private func loadMetadata(for url: URL) async {
        guard title == nil, iconImage == nil else { return }

        let provider = LPMetadataProvider()
        provider.timeout = 5.0

        do {
            let metadata = try await provider.startFetchingMetadata(for: url)

            guard !Task.isCancelled else {
                provider.cancel()
                return
            }

            let fetchedTitle = metadata.title

            var fetchedIcon: NSImage?
            if let iconProvider = metadata.iconProvider {
                fetchedIcon = await loadImage(from: iconProvider)
            }
            if fetchedIcon == nil, let imageProvider = metadata.imageProvider {
                fetchedIcon = await loadImage(from: imageProvider)
            }

            guard !Task.isCancelled else {
                provider.cancel()
                return
            }

            title = fetchedTitle
            iconImage = fetchedIcon
        } catch {}
    }

    private func loadImage(from provider: NSItemProvider) async -> NSImage? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: NSImage.self) { image, _ in
                continuation.resume(returning: image as? NSImage)
            }
        }
    }
}
