//
//  FloatingDragPreviewCardView.swift
//  Clipboard
//
//  Created by crown on 2026/3/31.
//

import AppKit
import SwiftUI

struct FloatingDragPreviewCardView: View {
    let model: PasteboardModel
    let enableLinkPreview: Bool
    let keyword: String

    var body: some View {
        HStack(alignment: .center, spacing: Const.space10) {
            FloatingPreviewAppIconView(appPath: model.appPath)
                .padding(.leading, Const.space6)

            floatingContent
                .padding(.vertical, Const.space4)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: contentAlignment
                )

            Spacer(minLength: 0)
        }
        .frame(
            width: Const.cardSize,
            height: FloatConst.cardHeight
        )
        .background(model.backgroundColor)
        .clipShape(.rect(cornerRadius: Const.radius))
    }

    @ViewBuilder
    private var floatingContent: some View {
        switch model.type {
        case .image:
            FloatingPreviewImageThumbnailView(model: model)
                .clipShape(.rect(cornerRadius: 6))
        case .color:
            Text(model.colorDisplayText)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .foregroundStyle(model.colors().1)
        case .file:
            if let paths = model.cachedFilePaths, !paths.isEmpty {
                if paths.count > 1 {
                    FloatingPreviewMultipleFilesView(paths: paths)
                } else if let firstPath = paths.first {
                    FloatingPreviewSingleFileView(path: firstPath)
                }
            }
        case .rich:
            if model.hasBgColor {
                Image(nsImage: model.richDragPreviewImage(
                    keyword: keyword,
                    size: CGSize(
                        width: Const.cardSize - 28 - Const.space10 - Const.space6,
                        height: FloatConst.cardHeight
                    ),
                    inset: CGSize(width: Const.space6, height: Const.space2)
                ))
                .clipShape(.rect(cornerRadius: 4))
            } else {
                plainTextContent
            }
        case .link:
            if enableLinkPreview {
                FloatingDragLinkPreviewView(
                    model: model,
                    searchKeyword: keyword
                )
            } else {
                plainTextContent
            }
        default:
            plainTextContent
        }
    }

    private var plainTextContent: some View {
        Text(model.highlightedPlainText(keyword: keyword))
    }

    private var contentAlignment: Alignment {
        model.pasteboardType.isText() || model.pasteboardType.isFile()
            ? .leading : .center
    }
}

private struct FloatingPreviewSingleFileView: View {
    let path: String

    private var fileURL: URL {
        URL(filePath: path)
    }

    private var fileName: String {
        fileURL.lastPathComponent
    }

    var body: some View {
        HStack(spacing: Const.space8) {
            FileThumbnailView(fileURLString: path, maxSize: 32)
                .frame(width: 32, height: 32)

            Text(fileName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)
        }
    }
}

private struct FloatingPreviewMultipleFilesView: View {
    let paths: [String]

    var body: some View {
        HStack(spacing: Const.space8) {
            Image(systemName: "folder.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.accentColor.opacity(0.6))
                .frame(width: 24, height: 24)

            Text(.fileCount(paths.count))
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }
}

private struct FloatingPreviewAppIconView: View {
    let appPath: String

    private var icon: NSImage {
        if let cached = AppIconCache.shared.getCachedIcon(forPath: appPath) {
            return cached
        }
        return NSWorkspace.shared.icon(forFile: appPath)
    }

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
    }
}

private struct FloatingPreviewImageThumbnailView: View {
    let model: PasteboardModel

    private var thumbnail: NSImage? {
        model.thumbnail() ?? NSImage(data: model.data)
    }

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(Const.space8)
            }
        }
        .frame(width: 44, height: 44)
    }
}

private struct FloatingDragLinkPreviewView: View {
    let model: PasteboardModel
    let searchKeyword: String

    private var url: URL? {
        model.attributeString.string.asCompleteURL()
    }

    var body: some View {
        HStack(spacing: Const.space8) {
            Image(systemName: "link")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.1))
                .clipShape(.rect(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(url?.host() ?? model.attributeString.string)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if searchKeyword.isEmpty {
                    Text(model.attributeString.string)
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
}
