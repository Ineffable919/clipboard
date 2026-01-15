//
//  FloatingView.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import SwiftUI

struct FloatingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppEnvironment.self) private var env
    @AppStorage(PrefKey.backgroundType.rawValue) private var backgroundTypeRaw =
        0
    @AppStorage(PrefKey.glassMaterial.rawValue) private var glassMaterialRaw = 2

    private var backgroundType: BackgroundType {
        .init(rawValue: backgroundTypeRaw) ?? .liquid
    }

    private var glassMaterial: GlassMaterial {
        .init(rawValue: glassMaterialRaw) ?? .regular
    }

    private let pd = PasteDataStore.main

    @Namespace private var namespace

    var body: some View {
        if #available(macOS 26.0, *) {
            ZStack(alignment: .top) {
                FloatingHistoryView()
                    .glassEffect(.regular, in: .rect)

                FloatingHeaderView()
                    .glassEffect(.regular, in: .rect)

                VStack {
                    Spacer()
                    FloatingFooterView(itemCount: pd.totalCount)
                        .frame(height: FloatingConst.footerHeight)
                        .glassEffect(.regular, in: .rect)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(.rect(cornerRadius: Const.radius))

        } else {
            ZStack(alignment: .top) {
                FloatingHistoryView()
                    .background(mainBackground)

                FloatingHeaderView()
                    .background(mainBackground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(.rect(cornerRadius: Const.radius))
        }
    }

    @ViewBuilder
    private var mainBackground: some View {
        if #available(macOS 26.0, *), backgroundType == .liquid {
            RoundedRectangle(cornerRadius: Const.radius)
                .fill(.clear)
                .glassEffect(
                    .regular,
                    in: .rect(cornerRadius: Const.radius)
                )
        } else {
            Rectangle()
                .fill(glassMaterial.material)
        }
    }
}

// MARK: - 常量

enum FloatingConst {
    static let headerHeight: CGFloat = 90.0
    static let footerHeight: CGFloat = 32.0
    static let cardWidth: CGFloat = 330.0
    static let cardSpacing: CGFloat = 10.0
    static let horizontalPadding: CGFloat = 16.0
}

#Preview {
    let env = AppEnvironment()
    FloatingView()
        .environment(env)
        .frame(width: 350, height: 600)
}
