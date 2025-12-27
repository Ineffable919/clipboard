//
//  CardContentView.swift
//  Clipboard
//
//  Created by crown on 2025/9/22.
//

import SwiftUI

struct CardContentView: View {
    let model: PasteboardModel
    let keyword: String
    let enableLinkPreview: Bool

    init(model: PasteboardModel, keyword: String = "", enableLinkPreview: Bool = false) {
        self.model = model
        self.keyword = keyword
        self.enableLinkPreview = enableLinkPreview
    }

    var body: some View {
        switch model.type {
        case .link:
            if enableLinkPreview {
                LinkPreviewCardView(model: model)
            } else {
                StringContentView(model: model, keyword: keyword)
            }
        case .color:
            CSSView(model: model)
        case .string:
            StringContentView(model: model, keyword: keyword)
        case .rich:
            RichContentView(model: model, keyword: keyword)
        case .file:
            FileContentView(model: model)
        case .image:
            ImageContentView(model: model)
        default:
            EmptyView()
        }
    }
}

struct CSSView: View {
    var model: PasteboardModel
    var body: some View {
        VStack(alignment: .center) {
            Text(model.attributeString.string)
                .font(.title2)
                .foregroundStyle(.primary)
        }
        .frame(
            width: Const.cardSize,
            height: Const.cntSize,
            alignment: .center,
        )
        .background(Color(nsColor: NSColor(hex: model.attributeString.string)))
    }
}

struct StringContentView: View {
    var model: PasteboardModel
    var keyword: String

    var body: some View {
        if keyword.isEmpty {
            Text(model.attributeString.string)
                .textCardStyle()
        } else {
            Text(model.highlightedPlainText(keyword: keyword))
                .textCardStyle()
        }
    }
}

struct RichContentView: View {
    var model: PasteboardModel
    var keyword: String

    var body: some View {
        if model.hasBgColor {
            if keyword.isEmpty {
                Text(model.attributed())
                    .textCardStyle()
            } else {
                Text(model.highlightedRichText(keyword: keyword))
                    .textCardStyle()
            }
        } else {
            if keyword.isEmpty {
                Text(model.attributeString.string)
                    .textCardStyle()
            } else {
                Text(model.highlightedPlainText(keyword: keyword))
                    .textCardStyle()
            }
        }
    }
}

struct FileContentView: View {
    var model: PasteboardModel

    var body: some View {
        if let fileUrls = model.cachedFilePaths {
            if fileUrls.count > 1 {
                MultipleFilesView(fileURLs: fileUrls)
            } else if let firstURL = fileUrls.first {
                FileThumbnailView(fileURLString: firstURL)
                    .padding(Const.space12)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .top,
                    )
            } else {
                VStack(alignment: .center) {
                    Image(systemName: "doc.text")
                        .resizable()
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                        .frame(width: 48.0, height: 48.0)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center,
                )
            }
        }
    }
}

struct ImageContentView: View {
    var model: PasteboardModel
    @State private var thumbnail: NSImage?
    @State private var isLoading = false
    @State private var loadingTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            CheckerboardBackground()
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "photo.badge.arrow.down")
                        .resizable()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, height: 48, alignment: .center)
                }
            }
        }
        .frame(
            maxWidth: Const.cardSize,
            maxHeight: Const.cntSize,
            alignment: .center,
        )
        .clipShape(Const.contentShape)
        .onAppear(perform: loadImage)
        .onDisappear {
            loadingTask?.cancel()
            loadingTask = nil
        }
    }

    private func loadImage() {
        guard thumbnail == nil else { return }
        isLoading = true

        loadingTask?.cancel()
        loadingTask = Task {
            guard !Task.isCancelled else { return }

            let loadedImage = await Task.detached {
                await model.thumbnail()
            }.value

            guard !Task.isCancelled else { return }
            await MainActor.run {
                thumbnail = loadedImage
                isLoading = false
            }
        }
    }
}

struct CheckerboardBackground: View {
    let squareSize: CGFloat = 8
    @Environment(\.colorScheme) var colorScheme

    var lightColor: Color {
        colorScheme == .light ? Color.white : Color.black.opacity(0.2)
    }

    var darkColor: Color {
        colorScheme == .light
            ? Const.lightImageColor
            : Const.darkImageColor
    }

    var body: some View {
        Canvas { context, size in
            let rows = Int(ceil(size.height / squareSize))
            let cols = Int(ceil(size.width / squareSize))

            for row in 0 ..< rows {
                for col in 0 ..< cols {
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize,
                    )

                    let isEven = (row + col) % 2 == 0
                    let color = isEven ? lightColor : darkColor

                    context.fill(
                        Path(rect),
                        with: .color(color),
                    )
                }
            }
        }
    }
}
