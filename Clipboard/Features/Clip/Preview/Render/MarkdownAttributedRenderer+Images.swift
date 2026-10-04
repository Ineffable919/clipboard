//
//  MarkdownAttributedRenderer+Images.swift
//  Clipboard
//
//  Markdown 富文本图片加载。
//

import AppKit

extension MarkdownAttributedRenderer {
    @MainActor
    static func loadImages(into result: NSMutableAttributedString) async {
        var imageRanges: [(range: NSRange, source: String)] = []
        result.enumerateAttribute(
            .markdownImageSource,
            in: NSRange(location: 0, length: result.length)
        ) { value, range, _ in
            if let source = value as? String {
                imageRanges.append((range, source))
            }
        }

        // 逆序替换以保证 range 不偏移
        for item in imageRanges.reversed() {
            guard let url = URL(string: item.source) else { continue }
            let data: Data?
            if url.isFileURL {
                data = await Task.detached { try? Data(contentsOf: url) }.value
            } else if url.scheme == "https" || url.scheme == "http" {
                data = try? await URLSession.shared.data(from: url).0
            } else {
                continue
            }
            guard let data, let image = NSImage(data: data) else { continue }
            let attachment = NSTextAttachment()
            attachment.image = image
            let maximumWidth: CGFloat = 400
            let width = min(image.size.width, maximumWidth)
            let height = image.size.height * (width / image.size.width)
            attachment.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            result.replaceCharacters(in: item.range, with: NSAttributedString(attachment: attachment))
        }
    }

    static func trimTrailingNewlines(_ result: NSMutableAttributedString) {
        while result.length > 0,
              (result.string as NSString).substring(from: result.length - 1) == "\n" {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
    }
}
