//
//  AsyncThumbnailView.swift
//  Clipboard
//
//  Created by crown on 2025/9/24.
//

import SwiftUI

struct AsyncThumbnailView: View {
    let fileURL: URL
    let maxSize: CGFloat

    @State private var thumbnail: NSImage?
    @State private var isLoading: Bool = true
    @State private var loadingFailed: Bool = false

    init(fileURL: URL, maxSize: CGFloat = 128) {
        self.fileURL = fileURL
        self.maxSize = maxSize
    }

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: maxSize,
                        maxHeight: maxSize,
                    )
            } else {
                Image(nsImage: ThumbnailView.shared.getSystemIcon(for: fileURL))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: maxSize, maxHeight: maxSize)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: thumbnail)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: fileURL) {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        isLoading = true
        thumbnail = nil
        loadingFailed = false

        ThumbnailView.shared.generateFinderStyleThumbnail(for: fileURL) {
            nsImage in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.2)) {
                    thumbnail = nsImage
                    isLoading = false
                    loadingFailed = nsImage == nil
                }
            }
        }
    }
}

struct FileThumbnailView: View {
    let fileURLString: String
    let maxSize: CGFloat

    init(fileURLString: String, maxSize: CGFloat = 128) {
        self.fileURLString = fileURLString
        self.maxSize = maxSize
    }

    var body: some View {
        let fileURL = URL(fileURLWithPath: fileURLString)

        if FileManager.default.fileExists(atPath: fileURLString) {
            AsyncThumbnailView(fileURL: fileURL, maxSize: maxSize)
        } else {
            Image(nsImage: ThumbnailView.shared.getSystemIcon(for: fileURL))
                .resizable()
                .scaledToFit()
                .frame(maxWidth: maxSize, maxHeight: maxSize)
        }
    }
}

struct MultipleFilesView: View {
    let fileURLs: [String]
    let maxSize: CGFloat

    init(fileURLs: [String], maxSize: CGFloat = 128) {
        self.fileURLs = fileURLs
        self.maxSize = maxSize
    }

    var body: some View {
        ZStack {
            ForEach(
                Array(fileURLs.prefix(4).enumerated().reversed()),
                id: \.offset,
            ) { index, urlString in
                FileThumbnailView(
                    fileURLString: urlString,
                    maxSize: maxSize * 0.5,
                )
                .clipShape(RoundedRectangle(cornerRadius: Const.radius))
                .offset(
                    x: CGFloat(index * 20),
                    y: CGFloat(-index * 10),
                )
            }
        }
        .frame(width: maxSize, height: maxSize)
    }
}

// MARK: - Previews

#if DEBUG
    struct AsyncThumbnailView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                AsyncThumbnailView(
                    fileURL: URL(fileURLWithPath: "/Applications/Safari.app"),
                    maxSize: 128,
                )
                .previewDisplayName("Single File")

                FileThumbnailView(
                    fileURLString: "/Users/Shared",
                    maxSize: 128,
                )
                .previewDisplayName("Folder")

                MultipleFilesView(
                    fileURLs: [
                        "/Applications/Google Chrome.app",
                        "/Applications/WeChat.app",
                        "/Applications/企业微信.app",
                        "/Applications/Clipboard.app",
                    ],
                    maxSize: 128,
                )
                .previewDisplayName("Four Files")

                MultipleFilesView(
                    fileURLs: [
                        "/Applications/Google Chrome.app",
                        "/Applications/WeChat.app",
                        "/Applications/企业微信.app",
                        "/Applications/Microsoft Word.app",
                        "/Applications/Clipboard.app",
                    ],
                    maxSize: 128,
                )
                .previewDisplayName("Multiple Files")
            }
            .frame(width: 235, height: 235)
            .padding()
        }
    }
#endif
