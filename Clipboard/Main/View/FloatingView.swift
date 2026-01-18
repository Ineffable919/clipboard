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
    @AppStorage(PrefKey.backgroundType.rawValue) private var backgroundTypeRaw = 0
    @AppStorage(PrefKey.glassMaterial.rawValue) private var glassMaterialRaw = 2

    private var backgroundType: BackgroundType {
        .init(rawValue: backgroundTypeRaw) ?? .liquid
    }

    private var glassMaterial: GlassMaterial {
        .init(rawValue: glassMaterialRaw) ?? .regular
    }

    var body: some View {
        contentStack
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(.rect(cornerRadius: Const.radius))
            .conditionalShadow()
    }

    private var contentStack: some View {
        ZStack(alignment: .top) {
            FloatingHistoryView()
                .background(mainBackground)

            FloatingHeaderView()
                .background(mainBackground)

            VStack {
                Spacer()
                FloatingFooterView()
                    .background(mainBackground)
            }
        }
    }

    @ViewBuilder
    private var mainBackground: some View {
        if #available(macOS 26.0, *), backgroundType == .liquid {
            Rectangle()
                .fill(.clear)
                .glassEffect(in: .rect)
        } else {
            Rectangle()
                .fill(glassMaterial.material)
        }
    }
}

// MARK: - 常量

enum FloatConst {
    static let headerHeight: CGFloat = 90.0
    static let footerHeight: CGFloat = 32.0
    static let cardWidth: CGFloat = 330.0
    static let cardHeight: CGFloat = 60.0
    static let cardSpacing: CGFloat = 10.0
    static let horizontalPadding: CGFloat = 16.0
    static let floatWindowWidth: CGFloat = 350.0
    static let floatWindowHeight: CGFloat = 650.0
}

// MARK: - View Extension

private extension View {
    @ViewBuilder
    func conditionalShadow() -> some View {
        if #available(macOS 26.0, *) {
            shadow(color: Const.cardShadowColor, radius: 8.0, x: 0, y: 2)
                .overlay {
                    RoundedRectangle(cornerRadius: Const.radius)
                        .stroke(.separator, lineWidth: 1.0)
                }
        } else {
            self
        }
    }
}

#Preview {
    let env = AppEnvironment()
    FloatingView()
        .environment(env)
        .frame(width: 350, height: 650)
        .padding()
}
