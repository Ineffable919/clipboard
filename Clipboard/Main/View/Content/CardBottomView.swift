//
//  CardBottomView.swift
//  Clipboard
//
//  Created by crown on 2025/9/23.
//

import SwiftUI

struct CardBottomView: View {
    var model: PasteboardModel
    @AppStorage(PrefKey.enableLinkPreview.rawValue)
    private var enableLinkPreview: Bool = PasteUserDefaults.enableLinkPreview

    @ViewBuilder
    var body: some View {
        if model.type == .image {
            let intro = model.introString()
            Text(intro)
                .padding(Const.space4)
                .font(.callout)
                .foregroundStyle(.secondary)
                .background(Color(.controlBackgroundColor).opacity(0.9))
                .cornerRadius(Const.radius)
                .frame(maxHeight: Const.bottomSize, alignment: .bottom)
                .padding(.bottom, Const.space4)
        } else if model.url != nil, enableLinkPreview {
            EmptyView()
        } else {
            CommonBottomView(model: model)
        }
    }
}

struct CommonBottomView: View {
    var model: PasteboardModel

    var body: some View {
        let (baseColor, textColor) = model.colors()
        let needsMask = calculateNeedsMask()

        Text(model.introString())
            .font(.callout)
            .lineLimit(2)
            .truncationMode(.head)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(textColor)
            .padding(.horizontal, Const.space12)
            .padding(.bottom, Const.space4)
            .frame(
                width: Const.cardSize
            )
            .background {
                if needsMask {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: baseColor, location: 0.0),
                            .init(color: baseColor, location: 0.35),
                            .init(color: baseColor.opacity(0.9), location: 0.65),
                            .init(color: baseColor.opacity(0.8), location: 0.85),
                            .init(color: .clear, location: 1.0),
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                }
            }
    }

    private func calculateNeedsMask() -> Bool {
        guard let data = model.showData,
              let text = String(data: data, encoding: .utf8),
              !text.isEmpty
        else {
            return false
        }

        let textHeight = calculateTextHeight(text: text)
        return textHeight > (Const.cntSize - Const.bottomSize)
    }

    /// 计算文本实际渲染高度
    private func calculateTextHeight(text: String) -> CGFloat {
        let font = NSFont.preferredFont(forTextStyle: .callout)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        if normalized.hasSuffix("\n") {
            normalized.append(" ")
        }

        let availableWidth = Const.cardSize - (Const.space12 * 2)
        let constraintRect = CGSize(
            width: max(0, availableWidth),
            height: .greatestFiniteMagnitude
        )

        let boundingBox = (normalized as NSString).boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading, .usesDeviceMetrics],
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle,
            ],
            context: nil
        )

        return ceil(boundingBox.height) + Const.space8
    }
}
