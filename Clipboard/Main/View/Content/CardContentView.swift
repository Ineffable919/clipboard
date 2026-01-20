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
                LinkPreviewCardView(model: model, keyword: keyword)
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
        let (_, textColor) = model.colors()
        VStack(alignment: .center) {
            Text(model.attributeString.string)
                .font(.title2)
                .foregroundStyle(textColor)
        }
        .frame(
            width: Const.cardSize,
            height: Const.cntSize,
            alignment: .center
        )
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
        Group {
            if let fileUrls = model.cachedFilePaths, !fileUrls.isEmpty {
                if fileUrls.count > 1 {
                    MultipleFilesView(fileURLs: fileUrls)
                } else {
                    FileThumbnailView(fileURLString: fileUrls[0])
                        .padding(Const.space12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            } else {
                FileIconPlaceholder()
            }
        }
    }
}

private struct FileIconPlaceholder: View {
    var body: some View {
        Image(systemName: "doc.text")
            .resizable()
            .foregroundStyle(Color.accentColor.opacity(0.8))
            .frame(width: 48, height: 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct ImageContentView: View {
    var model: PasteboardModel
    @State private var thumbnail: NSImage?
    @State private var isLoading = false
    @State private var loadingTask: Task<Void, Never>?
    @State private var cachedContentMode: ContentMode = .fit

    private static let containerSize = CGSize(width: Const.cardSize, height: Const.cntSize)
    private static let containerRatio = Const.cardSize / Const.cntSize

    var body: some View {
        ZStack {
            CheckerboardBackground()
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: cachedContentMode)
                    .frame(width: Self.containerSize.width, height: Self.containerSize.height)
                    .clipped()
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "photo.badge.arrow.down")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
            }
        }
        .frame(width: Self.containerSize.width, height: Self.containerSize.height)
        .clipShape(Const.contentShape)
        .onAppear(perform: loadImage)
        .onDisappear {
            loadingTask?.cancel()
            loadingTask = nil
        }
    }

    private func loadImage() {
        guard thumbnail == nil, !isLoading else { return }
        isLoading = true

        loadingTask = Task {
            guard !Task.isCancelled else { return }

            let loadedImage = await model.loadThumbnail()

            guard !Task.isCancelled, let image = loadedImage else {
                await MainActor.run { isLoading = false }
                return
            }

            // 预计算 contentMode
            let imageRatio = image.size.width / image.size.height
            let ratioDiff = abs(imageRatio - Self.containerRatio)
            let mode: ContentMode = ratioDiff < 0.5 ? .fill : .fit

            await MainActor.run {
                cachedContentMode = mode
                thumbnail = image
                isLoading = false
            }
        }
    }
}

struct CheckerboardBackground: View {
    @Environment(\.colorScheme) var colorScheme

    private var backgroundImage: NSImage {
        CheckerboardCache.shared.image(for: colorScheme)
    }

    var body: some View {
        Image(nsImage: backgroundImage)
            .resizable(resizingMode: .tile)
    }
}

private final class CheckerboardCache: @unchecked Sendable {
    static let shared = CheckerboardCache()

    private let squareSize: CGFloat = 8
    private var lightImage: NSImage?
    private var darkImage: NSImage?
    private let lock = NSLock()

    func image(for colorScheme: ColorScheme) -> NSImage {
        lock.lock()
        defer { lock.unlock() }

        if colorScheme == .light {
            if let cached = lightImage { return cached }
            let img = createCheckerboard(
                light: Const.lightImageShallowColor,
                dark: Const.lightImageDeepColor
            )
            lightImage = img
            return img
        } else {
            if let cached = darkImage { return cached }
            let img = createCheckerboard(
                light: Const.darkImageShallowColor,
                dark: Const.darkImageDeepColor
            )
            darkImage = img
            return img
        }
    }

    private func createCheckerboard(light: NSColor, dark: NSColor) -> NSImage {
        let tileSize = squareSize * 2
        let image = NSImage(size: NSSize(width: tileSize, height: tileSize))
        image.lockFocus()

        light.setFill()
        NSRect(x: 0, y: 0, width: squareSize, height: squareSize).fill()
        NSRect(x: squareSize, y: squareSize, width: squareSize, height: squareSize).fill()

        dark.setFill()
        NSRect(x: squareSize, y: 0, width: squareSize, height: squareSize).fill()
        NSRect(x: 0, y: squareSize, width: squareSize, height: squareSize).fill()

        image.unlockFocus()
        return image
    }
}
