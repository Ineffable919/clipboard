//
//  CardContentView.swift
//  Clipboard
//
//  Created by crown on 2025/9/22.
//

import SwiftUI
import WebKit

struct CardContentView: View {
    var model: PasteboardModel
    private let pd = PasteDataStore.main
    @AppStorage(PrefKey.enableLinkPreview.rawValue)
    private var enableLinkPreview: Bool = PasteUserDefaults.enableLinkPreview

    @ViewBuilder
    var body: some View {
        let keyword = pd.lastDataChangeType == .searchFilter
            ? pd.currentSearchKeyword
            : ""

        switch model.type {
        case .link:
            if enableLinkPreview {
                LinkPreviewCard(model: model)
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

struct LinkPreviewCard: View {
    @Environment(\.colorScheme) var colorScheme

    var model: PasteboardModel
    @State private var favicon: NSImage?
    @State private var pageTitle: String = ""
    @State private var isLoading: Bool = false
    @State private var loadingTask: Task<Void, Never>?
    @State private var displayTitle: String = ""

    var body: some View {
        if let url = model.url {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    if let favicon {
                        Image(nsImage: favicon)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 42, height: 42)
                    } else {
                        Image(systemName: "link")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 42, height: 42)
                            .foregroundColor(.accentColor)
                    }
                }
                .frame(
                    width: Const.cardSize,
                    height: Const.cntSize - 48,
                )
                .background(
                    colorScheme == .light
                        ? Const.lightBackground : Const.darkBackground,
                )

                VStack(alignment: .leading, spacing: 4) {
                    if !displayTitle.isEmpty {
                        Text(displayTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Text(url.host ?? url.absoluteString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(Const.space8)
                .frame(
                    width: Const.cardSize,
                    height: 48,
                    alignment: .leading,
                )
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .onAppear {
                if !isLoading, favicon == nil, displayTitle.isEmpty {
                    loadContent(from: url)
                }
            }
            .onDisappear {
                loadingTask?.cancel()
                loadingTask = nil
            }
        }
    }

    private func loadContent(from url: URL) {
        guard !isLoading else { return }
        isLoading = true

        loadingTask?.cancel()

        loadingTask = Task {
            await loadPageMetadata(from: url)

            guard !Task.isCancelled else { return }
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func loadPageMetadata(from url: URL) async {
        guard !Task.isCancelled else { return }

        await MainActor.run {
            displayTitle = url.host ?? ""
        }

        let session = URLSession.shared

        await loadFavicon(from: url, session: session)
        guard !Task.isCancelled else { return }

        await loadPageTitle(from: url, session: session)
    }

    private func loadFavicon(from url: URL, session: URLSession) async {
        guard !Task.isCancelled else { return }

        if let host = url.host {
            let scheme = url.scheme ?? "https"
            let base = URL(string: "\(scheme)://\(host)")!
            let fallbacks = [
                base.appendingPathComponent("favicon.ico"),
                base.appendingPathComponent("apple-touch-icon.png"),
                base.appendingPathComponent("favicon.png"),
            ]
            for u in fallbacks {
                guard !Task.isCancelled else { return }
                if let img = await fetchImage(u, session: session) {
                    await MainActor.run { favicon = img }
                    return
                }
            }
        }

        guard !Task.isCancelled else { return }

        do {
            var request = URLRequest(url: url)
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)",
                forHTTPHeaderField: "User-Agent",
            )
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 5.0

            let (data, _) = try await session.data(for: request)
            guard !Task.isCancelled else { return }

            if let html = String(data: data, encoding: .utf8),
               let iconURL = parseFirstHTMLIconURL(html: html, baseURL: url),
               let img = await fetchImage(iconURL, session: session)
            {
                await MainActor.run { favicon = img }
                return
            }
        } catch {}
    }

    private func parseFirstHTMLIconURL(html: String, baseURL: URL) -> URL? {
        let pattern =
            "<link[^>]*rel=\\\"([^\\\"]*)\\\"[^>]*href=\\\"([^\\\"]+)\\\"[^>]*>"
        guard
            let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive],
            )
        else { return nil }
        let ns = html as NSString
        for m in regex.matches(
            in: html,
            range: NSRange(location: 0, length: ns.length),
        ) {
            guard m.numberOfRanges >= 3 else { continue }
            let rel = ns.substring(with: m.range(at: 1)).lowercased()
            if rel.contains("icon") {
                let href = ns.substring(with: m.range(at: 2))
                if href.hasPrefix("//"), let scheme = baseURL.scheme {
                    return URL(string: "\(scheme):\(href)")
                }
                return URL(string: href, relativeTo: baseURL)?.absoluteURL
            }
        }
        return nil
    }

    private func fetchImage(_ url: URL, session: URLSession) async -> NSImage? {
        guard !Task.isCancelled else { return nil }

        // data:image/*;base64, ...
        if url.scheme == "data" {
            if let dataRange = url.absoluteString.range(of: ",") {
                let b64 = String(url.absoluteString[dataRange.upperBound...])
                if let data = Data(base64Encoded: b64),
                   let img = NSImage(data: data)
                {
                    img.cacheMode = .bySize
                    return img
                }
            }
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(
            "image/avif,image/webp,image/apng,image/*;q=0.8,*/*;q=0.5",
            forHTTPHeaderField: "Accept",
        )
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)",
            forHTTPHeaderField: "User-Agent",
        )
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 5.0

        do {
            let (data, response) = try await session.data(for: request)
            guard !Task.isCancelled else { return nil }

            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                return nil
            }
            // macOS 对 ICO、PNG、JPEG 普遍支持；SVG 不一定支持，忽略 SVG
            if url.pathExtension.lowercased() == "svg" { return nil }
            if let image = NSImage(data: data), image.isValid {
                image.cacheMode = .bySize
                return image
            }
        } catch {}
        return nil
    }

    private func loadPageTitle(from url: URL, session: URLSession) async {
        guard !Task.isCancelled else { return }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)",
                forHTTPHeaderField: "User-Agent",
            )
            request.cachePolicy = .returnCacheDataElseLoad

            let (data, _) = try await session.data(for: request)
            guard !Task.isCancelled else { return }

            if let html = String(data: data, encoding: .utf8) {
                if let titleMatch = html.range(
                    of: "<title[^>]*>([^<]+)</title>",
                    options: [.regularExpression, .caseInsensitive],
                ) {
                    let titleHTML = String(html[titleMatch])
                    let title =
                        titleHTML
                            .replacingOccurrences(
                                of: "<[^>]+>",
                                with: "",
                                options: .regularExpression,
                            )
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !title.isEmpty, title != url.host {
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            displayTitle = title
                        }
                    }
                }
            }
        } catch {}
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
