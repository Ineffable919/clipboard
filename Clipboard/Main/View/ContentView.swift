//
//  ContentView.swift
//  clipboard
//
//  Created by crown on 2025/9/11.
//

import SwiftUI

// MARK: - ContentView

struct ContentView: View {
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

    var body: some View {
        VStack(spacing: 0) {
            ClipTopBarView()
            HistoryView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if #available(macOS 26.0, *), backgroundType == .liquid {
                RoundedRectangle(cornerRadius: Const.radius)
                    .fill(.clear)
                    .glassEffect(
                        .regular,
                        in: .rect(cornerRadius: Const.radius)
                    )
            } else {
                RoundedRectangle(cornerRadius: Const.radius)
                    .fill(glassMaterial.material)
            }
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
