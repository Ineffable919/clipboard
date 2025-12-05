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

        Text(model.introString())
            .font(.callout)
            .lineLimit(2)
            .truncationMode(.head)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(textColor)
            .padding(.horizontal, Const.space12)
            .padding(.bottom, Const.space4)
            .frame(
                width: Const.cardSize,
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
