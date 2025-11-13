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
            if let thumbnail = thumbnail {
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
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.thumbnail = nsImage
                    self.isLoading = false
                    self.loadingFailed = nsImage == nil
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
        VStack(spacing: 6) {
            if fileURLs.count <= 4 {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 4),
                        count: min(2, fileURLs.count)
                    ),
                    spacing: 4
                ) {
                    ForEach(
                        Array(fileURLs.prefix(4).enumerated()),
                        id: \.offset
                    ) { index, urlString in
                        FileThumbnailView(
                            fileURLString: urlString,
                            maxSize: fileURLs.count == 1 ? maxSize : maxSize / 2
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .frame(maxWidth: maxSize, maxHeight: maxSize)
            } else {
                ZStack {
                    ForEach(
                        Array(fileURLs.prefix(3).enumerated().reversed()),
                        id: \.offset
                    ) { index, urlString in
                        FileThumbnailView(
                            fileURLString: urlString,
                            maxSize: maxSize * 0.7
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .offset(
                            x: CGFloat(index * 20),
                            y: CGFloat(-index * 10)
                        )
                        .scaleEffect(1.0 - CGFloat(index) * 0.05)
                        .opacity(1.0 - CGFloat(index) * 0.15)
                    }
                }
                .frame(width: maxSize, height: maxSize)
            }
        }
        .frame(maxWidth: maxSize)
    }
}

// MARK: - Previews
#if DEBUG
    struct AsyncThumbnailView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                AsyncThumbnailView(
                    fileURL: URL(fileURLWithPath: "/Applications/Safari.app"),
                    maxSize: 128
                )
                .previewDisplayName("Single File")

                FileThumbnailView(
                    fileURLString: "/Users/Shared",
                    maxSize: 128
                )
                .previewDisplayName("Folder")

                MultipleFilesView(
                    fileURLs: [
                        "/Applications/Google Chrome.app",
                        "/Applications/WeChat.app",
                        "/Applications/企业微信.app",
                        "/Applications/Microsoft Word.app",
                    ],
                    maxSize: 128
                )
                .previewDisplayName("Four Files")

                MultipleFilesView(
                    fileURLs: [
                        "/Applications/Google Chrome.app",
                        "/Applications/WeChat.app",
                        "/Applications/企业微信.app",
                        "/Applications/Microsoft Word.app",
                        "/Applications/Microsoft Excel.app",
                    ],
                    maxSize: 128
                )
                .previewDisplayName("Multiple Files")
            }
            .frame(width: 235, height: 235)
            .padding()
        }
    }
#endif
