//
//  ContentView.swift
//  clipboard
//
//  Created by crown on 2025/9/11.
//

import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject private var env: AppEnvironment

    @AppStorage(PrefKey.backgroundType.rawValue) private var backgroundTypeRaw:
        Int = 0
    @AppStorage(PrefKey.glassMaterial.rawValue) private var glassMaterialRaw:
        Int = 2

    private var backgroundType: BackgroundType {
        .init(rawValue: backgroundTypeRaw) ?? .liquid
    }

    private var glassMaterial: GlassMaterial {
        .init(rawValue: glassMaterialRaw) ?? .regular
    }

    @ViewBuilder
    private func contentStack() -> some View {
        VStack(spacing: 0) {
            ClipTopBarView()
            HistoryView()
        }
    }

    @ViewBuilder
    private func materialBackground() -> some View {
        RoundedRectangle(cornerRadius: Const.radius)
            .fill(glassMaterial.material)
    }

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                if backgroundType == .liquid {
                    ZStack {
                        RoundedRectangle(cornerRadius: Const.radius)
                            .fill(Color.clear)
                            .glassEffect(
                                in: RoundedRectangle(cornerRadius: Const.radius),
                            )
                        contentStack()
                    }
                } else {
                    contentStack()
                        .background(materialBackground())
                }
            } else {
                contentStack()
                    .background(materialBackground())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    let env = AppEnvironment()
    ContentView()
        .environmentObject(env)
        .frame(width: 1000, height: 330.0)
}
