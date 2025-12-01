//
//  CardBottomView.swift
//  Clipboard
//
//  Created by crown on 2025/9/23.
//

import SwiftUI

struct CardBottomView: View {
    var model: PasteboardModel
    @AppStorage(PrefKey.enableLinkPreview.rawValue) private var enableLinkPreview: Bool =
        PasteUserDefaults.enableLinkPreview

    @ViewBuilder
    var body: some View {
        if model.type == .image {
            let intro = model.introString()
            Text(intro)
                .padding(4)
                .font(.callout)
                .foregroundStyle(.secondary)
                .background(Color(.controlBackgroundColor).opacity(0.9))
                .cornerRadius(Const.radius)
                .frame(maxHeight: Const.bottomSize, alignment: .bottom)
                .padding(.bottom, 4)
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

        let intro = model.introString()
        HStack {
            Text(intro)
                .font(.callout)
                .lineLimit(intro.count > 36 ? 2 : 1)
                .truncationMode(.head)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, intro.count > 36 ? 8 : 4)
        .frame(
            width: Const.cardSize,
            height: intro.count > 36 ? Const.bottomSize : Const.bottomSize - 16,
        )
        .background {
            if model.length > 250 {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: baseColor, location: 0.0),
                        .init(color: baseColor, location: 0.35),
                        .init(color: baseColor.opacity(0.9), location: 0.65),
                        .init(color: baseColor.opacity(0.8), location: 0.85),
                        .init(color: .clear, location: 1.0),
                    ]),
                    startPoint: .bottom,
                    endPoint: .top,
                )
                .clipShape(RoundedRectangle(cornerRadius: Const.radius))
            }
        }
    }
}
