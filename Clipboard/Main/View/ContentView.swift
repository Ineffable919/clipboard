//
//  ContentView.swift
//  clipboard
//
//  Created by crown on 2025/9/11.
//

import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @AppStorage(PrefKey.backgroundType.rawValue) private var backgroundTypeRaw =
        0
    @AppStorage(PrefKey.glassMaterial.rawValue) private var glassMaterialRaw = 2

    private var backgroundType: BackgroundType {
        .init(rawValue: backgroundTypeRaw) ?? .liquid
    }

    private var glassMaterial: GlassMaterial {
        .init(rawValue: glassMaterialRaw) ?? .regular
    }

    var body: some View {
        mainContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(BackgroundModifier(
                backgroundType: backgroundType,
                glassMaterial: glassMaterial
            ))
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            ClipTopBarView()
            HistoryView()
        }
    }
}

// MARK: - BackgroundModifier

private struct BackgroundModifier: ViewModifier {
    let backgroundType: BackgroundType
    let glassMaterial: GlassMaterial

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), backgroundType == .liquid {
            content
                .background(
                    RoundedRectangle(cornerRadius: Const.windowRadis)
                        .fill(.clear)
                        .glassEffect(
                            .regular,
                            in: .rect(cornerRadius: Const.windowRadis)
                        )
                )
        } else if #available(macOS 26.0, *) {
            content
                .background(glassMaterial.material)
                .clipShape(.rect(cornerRadius: Const.windowRadis))
        } else {
            content
                .background(glassMaterial.material)
        }
    }
}

// MARK: - Preview

#Preview {
    let env = AppEnvironment()
    ContentView()
        .environment(env)
        .frame(width: 1000, height: 330.0)
}
