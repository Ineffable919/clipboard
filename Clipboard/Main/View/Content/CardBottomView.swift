//
//  CardBottomView.swift
//  Clipboard
//
//  Created by crown on 2025/9/23.
//

import AppKit
import SwiftUI

struct CardBottomView: View {
    let model: PasteboardModel
    let enableLinkPreview: Bool

    var body: some View {
        switch model.type {
        case .image:
            ImageBottomView(introString: model.introString())
        case .link:
            if enableLinkPreview {
                EmptyView()
            } else {
                CommonBottomView(model: model)
            }
        case .color:
            EmptyView()
        default:
            CommonBottomView(model: model)
        }
    }
}

private struct ImageBottomView: View {
    let introString: String

    var body: some View {
        Text(introString)
            .padding(Const.space4)
            .font(.callout)
            .foregroundStyle(.secondary)
            .background(Color(.controlBackgroundColor).opacity(0.9))
            .clipShape(.rect(cornerRadius: Const.radius))
            .frame(maxHeight: Const.bottomSize, alignment: .bottom)
            .padding(.bottom, Const.space4)
    }
}

struct CommonBottomView: View {
    let model: PasteboardModel

    private let colors: (Color, Color)
    private let needsMask: Bool
    private let introString: String

    init(model: PasteboardModel) {
        self.model = model
        colors = model.colors()
        introString = model.introString()
        needsMask = Self.calculateNeedsMask(model: model)
    }

    var body: some View {
        let (baseColor, textColor) = colors

        ZStack(alignment: .bottom) {
            if needsMask {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: baseColor, location: 0.0),
                        .init(color: baseColor, location: 0.6),
                        .init(color: baseColor.opacity(0.8), location: 0.9),
                        .init(color: .clear, location: 1.0),
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            }

            Text(introString)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.head)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(textColor)
                .padding(.horizontal, Const.space12)
                .padding(
                    .bottom,
                    model.pasteboardType.isFile() ? Const.space8 : Const.space4
                )
                .frame(width: Const.cardSize)
        }
        .frame(maxHeight: model.pasteboardType.isFile() ? 28.0 : 24.0)
    }

    private static func calculateNeedsMask(model: PasteboardModel) -> Bool {
        guard model.pasteboardType.isText() else { return false }

        let contentTopPadding = Const.space8
        let contentHeightBeforeBottomOverlay = Const.cntSize - Const.bottomSize
        let contentTextHeight = calculateContentTextHeight(model: model)

        return (contentTopPadding + contentTextHeight)
            > contentHeightBeforeBottomOverlay
    }

    private static func calculateContentTextHeight(model: PasteboardModel)
        -> CGFloat
    {
        let availableWidth = Const.cardSize - Const.space10 - Const.space8
        let constraintRect = CGSize(
            width: max(0, availableWidth),
            height: .greatestFiniteMagnitude
        )

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let defaultFont = NSFont.preferredFont(forTextStyle: .body)

        let measuredAttributed = makeMeasuringAttributedString(
            base: model.attributeString,
            defaultFont: defaultFont,
            paragraphStyle: paragraphStyle
        )

        let boundingBox = measuredAttributed.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        return ceil(boundingBox.height)
    }

    private static func makeMeasuringAttributedString(
        base: NSAttributedString,
        defaultFont: NSFont,
        paragraphStyle: NSParagraphStyle
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: base)

        if mutable.string.contains("\r\n") {
            mutable.mutableString.replaceOccurrences(
                of: "\r\n",
                with: "\n",
                options: [],
                range: NSRange(location: 0, length: mutable.length)
            )
        }
        if mutable.string.hasSuffix("\n") {
            mutable.append(
                NSAttributedString(
                    string: " ",
                    attributes: [.font: defaultFont]
                )
            )
        }

        if mutable.length > 0,
           mutable.attribute(.font, at: 0, effectiveRange: nil) == nil
        {
            mutable.addAttribute(
                .font,
                value: defaultFont,
                range: NSRange(location: 0, length: mutable.length)
            )
        }

        mutable.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: mutable.length)
        )

        return mutable
    }
}
