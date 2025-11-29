//
//  ContentView.swift
//  clipboard
//
//  Created by crown on 2025/9/11.
//

import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @FocusState private var historyFocused: Bool
    @State private var pd = PasteDataStore.main

    var body: some View {
        if #available(macOS 26.0, *) {
            ZStack {
                RoundedRectangle(cornerRadius: Const.radius)
                    .fill(Color.clear)
                    .glassEffect(
                        in: RoundedRectangle(cornerRadius: Const.radius),
                    )
                VStack {
                    Spacer()
                    TopBarView()
                    HistoryAreaView(pd: pd)
                        .focusable()
                        .focusEffectDisabled()
                        .focused($historyFocused)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    historyFocused = true
                }
            }
        } else {
            VStack {
                Spacer()
                TopBarView()
                Spacer()
                HistoryAreaView(pd: pd)
                    .focusable()
                    .focusEffectDisabled()
                    .focused($historyFocused)
            }
            .padding(.bottom, Const.cardBottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    historyFocused = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .frame(width: 1000, height: 330.0)
}
