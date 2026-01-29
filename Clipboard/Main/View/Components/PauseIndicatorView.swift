//
//  PauseIndicatorView.swift
//  Clipboard
//
//  Created by crown on 2026/1/29.
//

import SwiftUI

struct PauseIndicatorView: View {
    var topBarVM: TopBarViewModel

    var body: some View {
        Button {
            topBarVM.resumePasteboard()
        } label: {
            HStack(spacing: Const.space6) {
                Image(systemName: "pause.fill")
                    .font(.system(size: Const.space8, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 16.0, height: 16.0)
                    .background(Color.accentColor, in: .circle)
                Text(topBarVM.formattedRemainingTime)
                    .font(
                        .system(size: 13.0, weight: .regular, design: .rounded)
                    )
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.leading, Const.space6)
            .padding(.trailing, Const.space10)
            .padding(.vertical, Const.space6)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .help("点击恢复记录")
    }
}
