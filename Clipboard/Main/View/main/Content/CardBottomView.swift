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
    let keyword: String

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
        case .file:
            FileBottomView(model: model, keyword: keyword)
        case .color:
            EmptyView()
        default:
            CommonBottomView(model: model)
        }
    }
}

private struct FileBottomView: View {
    let model: PasteboardModel
    let keyword: String

    var body: some View {
        let (_, textColor) = model.colors()

        if let cachePaths = model.cachedFilePaths {
            if cachePaths.count > 1 {
                Text(model.introString())
                    .font(.callout)
                    .foregroundStyle(textColor)
                    .padding(.bottom, Const.space4)
            } else {
                Group {
                    if keyword.isEmpty {
                        Text(model.introString())
                    } else {
                        Text(model.highlightedPlainText(keyword: keyword))
                    }
                }
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.head)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(textColor)
                .padding(.horizontal, Const.space12)
                .padding(.bottom, Const.space4)
                .frame(width: Const.cardSize)
            }
        }
    }
}

private struct ImageBottomView: View {
    let introString: String

    var body: some View {
        Text(introString)
            .padding(Const.space2)
            .multilineTextAlignment(.center)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(alignment: .bottom)
            .background(Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
            .clipShape(.rect(cornerRadius: 6.0))
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
        needsMask = model.needsBottomMask {
            ContentMaskCalculator.needsMask(for: model)
        }
    }

    var body: some View {
        let (baseColor, textColor) = colors

        ZStack(alignment: .bottom) {
            if needsMask {
                BottomGradientMaskView(baseColor: baseColor)
            }

            BottomIntroTextView(introString: introString, textColor: textColor)
        }
        .frame(maxHeight: 24.0)
    }
}

// MARK: - Bottom Gradient Mask View

private struct BottomGradientMaskView: View {
    let baseColor: Color

    var body: some View {
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
}

// MARK: - Bottom Intro Text View

private struct BottomIntroTextView: View {
    let introString: String
    let textColor: Color

    var body: some View {
        Text(introString)
            .font(.callout)
            .foregroundStyle(textColor)
            .padding(.horizontal, Const.space12)
            .padding(.bottom, Const.space4)
            .frame(width: Const.cardSize)
    }
}
