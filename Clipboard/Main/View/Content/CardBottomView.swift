//
//  CardBottomView.swift
//  Clipboard
//
//  Created by crown on 2025/9/23.
//

import AppKit
import SwiftUI

struct CardBottomView: View {
    var model: PasteboardModel
    @AppStorage(PrefKey.enableLinkPreview.rawValue)
    private var enableLinkPreview: Bool = PasteUserDefaults.enableLinkPreview

    @ViewBuilder
    var body: some View {
        switch model.type {
        case .image:
            Text(model.introString())
                .padding(Const.space4)
                .font(.callout)
                .foregroundStyle(.secondary)
                .background(Color(.controlBackgroundColor).opacity(0.9))
                .clipShape(.rect(cornerRadius: Const.radius))
                .frame(maxHeight: Const.bottomSize, alignment: .bottom)
                .padding(.bottom, Const.space4)
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

struct CommonBottomView: View {
    var model: PasteboardModel

    var body: some View {
        let (baseColor, textColor) = model.colors()
        let needsMask = calculateNeedsMask()

        ZStack(alignment: .bottom) {
            if needsMask {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: baseColor, location: 0.0),
                        .init(color: baseColor, location: 0.6),
                        .init(
                            color: baseColor.opacity(0.8),
                            location: 0.9,
                        ),
                        .init(color: .clear, location: 1.0),
                    ]),
                    startPoint: .bottom,
                    endPoint: .top,
                )
            }

            Text(model.introString())
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.head)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(textColor)
                .padding(.horizontal, Const.space12)
                .padding(.bottom, Const.space8)
                .frame(
                    width: Const.cardSize,
                )
        }
        .frame(maxHeight: 32.0)
    }

    private func calculateNeedsMask() -> Bool {
        guard model.pasteboardType.isText() else {
            return false
        }

        let contentTopPadding = Const.space8
        let contentHeightBeforeBottomOverlay = Const.cntSize - Const.bottomSize

        let contentTextHeight = calculateContentTextHeight()
        return (contentTopPadding + contentTextHeight)
            > contentHeightBeforeBottomOverlay
    }

    /// 计算内容区文本（`CardContentView`）的实际渲染高度，用于判断是否需要底部遮罩。
    private func calculateContentTextHeight() -> CGFloat {
        let availableWidth = Const.cardSize - Const.space10 - Const.space8
        let constraintRect = CGSize(
            width: max(0, availableWidth),
            height: .greatestFiniteMagnitude,
        )

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let defaultFont = NSFont.preferredFont(forTextStyle: .body)

        let measuredAttributed = makeMeasuringAttributedString(
            base: model.attributeString,
            defaultFont: defaultFont,
            paragraphStyle: paragraphStyle,
        )

        let boundingBox = measuredAttributed.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil,
        )

        return ceil(boundingBox.height)
    }

    private func makeMeasuringAttributedString(
        base: NSAttributedString,
        defaultFont: NSFont,
        paragraphStyle: NSParagraphStyle,
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: base)

        // 处理 CRLF 以及末尾换行导致高度计算偏小的问题
        if mutable.string.contains("\r\n") {
            mutable.mutableString.replaceOccurrences(
                of: "\r\n",
                with: "\n",
                options: [],
                range: NSRange(location: 0, length: mutable.length),
            )
        }
        if mutable.string.hasSuffix("\n") {
            mutable.append(
                NSAttributedString(
                    string: " ",
                    attributes: [.font: defaultFont],
                ),
            )
        }

        if mutable.length > 0,
           mutable.attribute(.font, at: 0, effectiveRange: nil) == nil
        {
            mutable.addAttribute(
                .font,
                value: defaultFont,
                range: NSRange(location: 0, length: mutable.length),
            )
        }

        mutable.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: mutable.length),
        )

        return mutable
    }
}
