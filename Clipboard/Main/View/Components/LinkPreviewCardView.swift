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
    @State private var icon: NSImage?
    @State private var loadingTask: Task<Void, Never>?

    var body: some View {
        if let url = model.attributeString.string.asCompleteURL() {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 42, height: 42)
                    } else {
                        Image(systemName: "link")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 42, height: 42)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .frame(
                    width: Const.cardSize,
                    height: Const.cntSize - 48
                )
                .background(
                    colorScheme == .light
                        ? Const.lightBackground : Const.darkBackground
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title ?? url.host ?? "")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(url.host ?? url.absoluteString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(Const.space8)
                .frame(
                    width: Const.cardSize,
                    height: 48,
                    alignment: .leading
                )
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .onAppear {
                loadMetadata(for: url)
            }
            .onDisappear {
                loadingTask?.cancel()
                loadingTask = nil
            }
        }
    }

    private func loadMetadata(for url: URL) {
        guard title == nil, icon == nil else { return }

        loadingTask?.cancel()
        loadingTask = Task {
            let provider = LPMetadataProvider()
            provider.timeout = 5.0

            do {
                let metadata = try await provider.startFetchingMetadata(
                    for: url
                )

                guard !Task.isCancelled else {
                    provider.cancel()
                    return
                }

                let fetchedTitle = metadata.title
                var fetchedIcon: NSImage?

                if let iconProvider = metadata.iconProvider {
                    fetchedIcon = await loadImage(from: iconProvider)
                }

                guard !Task.isCancelled else {
                    provider.cancel()
                    return
                }

                await MainActor.run {
                    title = fetchedTitle
                    icon = fetchedIcon
                }
            } catch {}
        }
    }

    private func loadImage(from provider: NSItemProvider) async -> NSImage? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: NSImage.self) { image, _ in
                continuation.resume(returning: image as? NSImage)
            }
        }
    }
}
