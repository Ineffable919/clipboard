//
//  HistoryDragPreviewCardView.swift
//  Clipboard
//
//  Created by crown on 2026/3/31.
//

import AppKit
import SwiftUI

struct HistoryDragPreviewCardView: View {
    let model: PasteboardModel
    let enableLinkPreview: Bool
    let keyword: String

    var body: some View {
        VStack(spacing: 0) {
            HistoryDragCardHeadView(model: model)

            Group {
                switch model.type {
                case .link:
                    if enableLinkPreview {
                        HistoryDragLinkPreviewView(
                            model: model,
                            keyword: keyword
                        )
                    } else {
                        plainTextContent
                    }
                case .color:
                    HistoryDragColorPreviewView(model: model)
                case .rich:
                    if model.hasBgColor {
                        Image(nsImage: model.richDragPreviewImage(keyword: keyword))
                            .frame(width: Const.cardSize, height: Const.cntSize)
                    } else {
                        plainTextContent
                    }
                case .string:
                    plainTextContent
                case .file:
                    HistoryDragFilePreviewView(model: model)
                case .image:
                    HistoryDragImagePreviewView(model: model)
                default:
                    EmptyView()
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: model.pasteboardType.isText() ? .topLeading : .center
            )
            .background(model.backgroundColor)
            .clipShape(Const.contentShape)
        }
        .frame(width: Const.cardSize, height: Const.cardSize)
    }

    private var plainTextContent: some View {
        Text(model.highlightedPlainText(keyword: keyword))
            .textCardStyle()
    }
}

private struct HistoryDragCardHeadView: View {
    let model: PasteboardModel

    private var isDefault: Bool {
        model.group == -1
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.type.string)
                        .font(isDefault ? .headline : .title3)
                        .foregroundStyle(.white)

                    if isDefault {
                        Text(
                            model.timestamp.timeAgo(
                                relativeTo: TimeManager.shared.currentTime
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)

            if isDefault {
                HistoryDragAppIconView(appPath: model.appPath)
                    .offset(x: 15)
            }
        }
        .frame(height: Const.hdSize)
        .background(AppColorService.shared.color(for: model))
        .clipShape(Const.headShape)
    }
}

private struct HistoryDragAppIconView: View {
    let appPath: String

    private var icon: NSImage? {
        if let cached = AppIconCache.shared.getCachedIcon(forPath: appPath) {
            return cached
        }

        guard !appPath.isEmpty else { return nil }
        return NSWorkspace.shared.icon(forFile: appPath)
    }

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .frame(width: Const.iconSize, height: Const.iconSize)
    }
}

private struct HistoryDragColorPreviewView: View {
    let model: PasteboardModel

    var body: some View {
        let (_, textColor) = model.colors()
        VStack(alignment: .center) {
            Text(model.colorDisplayText)
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

private struct HistoryDragFilePreviewView: View {
    let model: PasteboardModel

    var body: some View {
        Group {
            if let fileURLs = model.cachedFilePaths, !fileURLs.isEmpty {
                if fileURLs.count > 1 {
                    VStack(spacing: Const.space8) {
                        Image(systemName: "folder.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.accentColor.opacity(0.6))
                            .frame(width: 40, height: 40)

                        Text(.fileCount(fileURLs.count))
                            .foregroundStyle(.primary)
                    }
                } else if let firstPath = fileURLs.first {
                    VStack(spacing: Const.space8) {
                        Image(
                            nsImage: NSWorkspace.shared.icon(forFile: firstPath)
                        )
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)

                        Text(URL(filePath: firstPath).lastPathComponent)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Const.space12)
                }
            } else {
                Image(systemName: "doc.text")
                    .resizable()
                    .foregroundStyle(Color.accentColor.opacity(0.8))
                    .frame(width: 48, height: 48)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .center
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HistoryDragImagePreviewView: View {
    let model: PasteboardModel

    private static let containerSize = CGSize(
        width: Const.cardSize,
        height: Const.cntSize
    )
    private static let containerRatio = Const.cardSize / Const.cntSize

    private var image: NSImage? {
        model.thumbnail() ?? NSImage(data: model.data)
    }

    private var contentMode: ContentMode {
        guard let image else { return .fit }
        let imageRatio = image.size.width / image.size.height
        let ratioDiff = abs(imageRatio - Self.containerRatio)
        return ratioDiff < 0.5 ? .fill : .fit
    }

    var body: some View {
        ZStack {
            CheckerboardBackground()
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: contentMode)
                    .frame(
                        width: Self.containerSize.width,
                        height: Self.containerSize.height
                    )
                    .clipped()
            } else {
                Image(systemName: "photo.badge.arrow.down")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
            }
        }
        .frame(
            width: Self.containerSize.width,
            height: Self.containerSize.height
        )
    }
}

private struct HistoryDragLinkPreviewView: View {
    let model: PasteboardModel
    let keyword: String
    @Environment(\.colorScheme) private var colorScheme

    private var url: URL? {
        model.attributeString.string.asCompleteURL()
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if url != nil {
                    Image(systemName: "link")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 42, height: 42)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "questionmark.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 42, height: 42)
                        .foregroundStyle(.secondary)
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

            VStack(alignment: .leading, spacing: Const.space4) {
                Text(url?.host() ?? model.attributeString.string)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if keyword.isEmpty {
                    Text(model.attributeString.string)
                } else {
                    Text(model.highlightedPlainText(keyword: keyword))
                }
            }
            .padding(Const.space8)
            .frame(
                width: Const.cardSize,
                height: 48,
                alignment: .leading
            )
            .background(.background)
        }
    }
}
