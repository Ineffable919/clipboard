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
    @AppStorage("enableLinkPreview") private var enableLinkPreview: Bool =
        PasteUserDefaults.enableLinkPreview

    @ViewBuilder
    var body: some View {
        switch model.type {
        case .string:
            if model.url != nil && enableLinkPreview {
                LinkPreviewCard(model: model)
            } else {
                StringContentView(model: model)
            }
        case .rich:
            RichContentView(model: model)
        case .file:
            FileContentView(model: model)
        case .image:
            ImageContentView(model: model)
        case .none:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }
}

struct LinkPreviewCard: View {
    @Environment(\.colorScheme) var colorScheme

    var model: PasteboardModel
    @State private var favicon: NSImage?
    @State private var pageTitle: String = ""
    @State private var isLoading: Bool = false
    @State private var loadingTask: Task<Void, Never>?

    var body: some View {
        if let url = model.url {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    if let favicon = favicon {
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
                    height: Const.cntSize - 48
                )
                .background(
                    colorScheme == .light
                        ? Const.lightBackground : Const.darkBackground
                )

                VStack(alignment: .leading, spacing: 4) {
                    if !pageTitle.isEmpty {
                        Text(pageTitle)
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
                .padding(8)
                .frame(
                    width: Const.cardSize,
                    height: 48,
                    alignment: .leading
                )
                .background(.windowBackground)
            }
            .onAppear {
                if !isLoading && favicon == nil && pageTitle.isEmpty {
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

            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func loadPageMetadata(from url: URL) async {
        await MainActor.run {
            pageTitle = url.host ?? ""
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 10.0
        let session = URLSession(configuration: config)

        async let faviconTask: () = loadFavicon(from: url, session: session)
        async let titleTask: () = loadPageTitle(from: url, session: session)

        let _ = await (faviconTask, titleTask)
    }

    private func loadFavicon(from url: URL, session: URLSession) async {
        if let host = url.host {
            let scheme = url.scheme ?? "https"
            let base = URL(string: "\(scheme)://\(host)")!
            let fallbacks = [
                base.appendingPathComponent("favicon.ico"),
                base.appendingPathComponent("apple-touch-icon.png"),
                base.appendingPathComponent("favicon.png"),
            ]
            for u in fallbacks {
                if let img = await fetchImage(u, session: session) {
                    await MainActor.run { self.favicon = img }
                    return
                }
            }
        }

        do {
            var request = URLRequest(url: url)
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)",
                forHTTPHeaderField: "User-Agent"
            )
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, _) = try await session.data(for: request)
            if let html = String(data: data, encoding: .utf8),
                let iconURL = parseFirstHTMLIconURL(html: html, baseURL: url),
                let img = await fetchImage(iconURL, session: session)
            {
                await MainActor.run { self.favicon = img }
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
                options: [.caseInsensitive]
            )
        else { return nil }
        let ns = html as NSString
        for m in regex.matches(
            in: html,
            range: NSRange(location: 0, length: ns.length)
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
        // data:image/*;base64, ...
        if url.scheme == "data" {
            if let dataRange = url.absoluteString.range(of: ",") {
                let b64 = String(url.absoluteString[dataRange.upperBound...])
                if let data = Data(base64Encoded: b64),
                    let img = NSImage(data: data)
                {
                    return img
                }
            }
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(
            "image/avif,image/webp,image/apng,image/*;q=0.8,*/*;q=0.5",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)",
            forHTTPHeaderField: "User-Agent"
        )
        request.cachePolicy = .returnCacheDataElseLoad
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                return nil
            }
            // macOS 对 ICO、PNG、JPEG 普遍支持；SVG 不一定支持，忽略 SVG
            if url.pathExtension.lowercased() == "svg" { return nil }
            if let image = NSImage(data: data), image.isValid { return image }
        } catch {}
        return nil
    }

    private func loadPageTitle(from url: URL, session: URLSession) async {
        do {
            let (data, _) = try await session.data(from: url)

            if let html = String(data: data, encoding: .utf8) {
                if let titleMatch = html.range(
                    of: "<title[^>]*>([^<]+)</title>",
                    options: [.regularExpression, .caseInsensitive]
                ) {
                    let titleHTML = String(html[titleMatch])
                    let title =
                        titleHTML
                        .replacingOccurrences(
                            of: "<[^>]+>",
                            with: "",
                            options: .regularExpression
                        )
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !title.isEmpty && title != url.host {
                        await MainActor.run {
                            self.pageTitle = title
                        }
                    }
                }
            }
        } catch {}
    }
}

struct StringContentView: View {
    var model: PasteboardModel

    var body: some View {
        Text(String(data: model.data, encoding: .utf8) ?? "")
            .lineLimit(12)
            .multilineTextAlignment(.leading)
    }
}

struct RichContentView: View {
    var model: PasteboardModel

    var body: some View {
        if model.attributeString.attribute(
            .backgroundColor,
            at: 0,
            effectiveRange: nil
        ) is NSColor {
            Text(model.attributed())
                .lineLimit(12)
                .multilineTextAlignment(.leading)
                .textSelection(.disabled)
        } else {
            Text(model.attributeString.string)
                .foregroundStyle(.primary)
                .lineLimit(12)
                .multilineTextAlignment(.leading)
        }
    }
}

struct FileContentView: View {
    var model: PasteboardModel

    var body: some View {
        if let url = String(data: model.data, encoding: .utf8) {
            let fileUrls = url.components(separatedBy: "\n").filter {
                !$0.isEmpty
            }
            if fileUrls.count > 1 {
                MultipleFilesView(fileURLs: fileUrls)
            } else if let firstURL = fileUrls.first {
                FileThumbnailView(fileURLString: firstURL)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .top
                    )
            } else {
                VStack(alignment: .center) {
                    Image(systemName: "doc.text")
                        .resizable()
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                        .frame(width: 48.0, height: 56.0)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
            }
        }
    }
}

struct ImageContentView: View {
    var model: PasteboardModel
    @State private var thumbnail: NSImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            CheckerboardBackground()
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, height: 48, alignment: .center)
                }
            }
        }
        .frame(
            maxWidth: Const.cardSize,
            maxHeight: Const.cntSize,
            alignment: .center
        )
        .clipShape(Const.contentShape)
        .onAppear(perform: loadImage)
    }

    private func loadImage() {
        guard thumbnail == nil else { return }
        isLoading = true
        Task {
            let loadedImage = await Task.detached {
                await model.thumbnail()
            }.value

            await MainActor.run {
                self.thumbnail = loadedImage
                self.isLoading = false
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
            ? Color(nsColor: NSColor(hex: "#f2f2f2"))
            : Color(nsColor: NSColor(hex: "#282828"))
    }

    var body: some View {
        Canvas { context, size in
            let rows = Int(ceil(size.height / squareSize))
            let cols = Int(ceil(size.width / squareSize))

            for row in 0..<rows {
                for col in 0..<cols {
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )

                    let isEven = (row + col) % 2 == 0
                    let color = isEven ? lightColor : darkColor

                    context.fill(
                        Path(rect),
                        with: .color(color)
                    )
                }
            }
        }
    }
}
