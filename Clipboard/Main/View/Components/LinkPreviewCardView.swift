//
//  LinkPreviewCardView.swift
//  Clipboard
//
//  Created by crown on 2025/9/22.
//

import LinkPresentation
import SwiftUI

struct LinkPreviewCardView: View {
    @Environment(\.colorScheme) var colorScheme

    let model: PasteboardModel

    @State private var title: String?
    @State private var previewImage: NSImage?
    @State private var iconImage: NSImage?

    var body: some View {
        if let url = model.attributeString.string.asCompleteURL() {
            VStack(spacing: 0) {
                imageSection
                    .frame(
                        width: Const.cardSize,
                        height: Const.cntSize - 48
                    )
                    .background(
                        colorScheme == .light
                            ? Const.lightBackground : Const.darkBackground
                    )

                infoSection(url: url)
                    .padding(Const.space8)
                    .frame(
                        width: Const.cardSize,
                        height: 48,
                        alignment: .leading
                    )
                    .background(.background)
            }
            .task {
                await loadMetadata(for: url)
            }
        }
    }

    @ViewBuilder
    private var imageSection: some View {
        if let previewImage {
            Image(nsImage: previewImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(.rect)
        } else if let iconImage {
            Image(nsImage: iconImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 42, height: 42)
        } else {
            Image(systemName: "link")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 42, height: 42)
                .foregroundStyle(.secondary)
        }
    }

    private func infoSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: Const.space4) {
            Text(title ?? url.host() ?? "")
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(url.absoluteString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func loadMetadata(for url: URL) async {
        guard title == nil, previewImage == nil, iconImage == nil else { return }

        let provider = LPMetadataProvider()
        provider.timeout = 5.0

        do {
            let metadata = try await provider.startFetchingMetadata(for: url)

            guard !Task.isCancelled else {
                provider.cancel()
                return
            }

            let fetchedTitle = metadata.title
            var fetchedPreviewImage: NSImage?
            var fetchedIconImage: NSImage?

            if let imageProvider = metadata.imageProvider {
                fetchedPreviewImage = await loadImage(from: imageProvider)
            }

            if fetchedPreviewImage == nil, let iconProvider = metadata.iconProvider {
                fetchedIconImage = await loadImage(from: iconProvider)
            }

            guard !Task.isCancelled else {
                provider.cancel()
                return
            }

            title = fetchedTitle
            previewImage = fetchedPreviewImage
            iconImage = fetchedIconImage
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
