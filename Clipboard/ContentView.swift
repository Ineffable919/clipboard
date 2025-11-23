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
                    HistoryAreaView()
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
                HistoryAreaView()
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

// MARK: - NSVisualEffect 背景

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = state
        v.isEmphasized = false
        return v
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}

// MARK: - Preview

#Preview {
    ContentView()
        .frame(width: 1000, height: 335)
}
