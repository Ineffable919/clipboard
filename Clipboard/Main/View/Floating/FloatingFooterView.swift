//
//  FloatingFooterView.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import SwiftUI

struct FloatingFooterView: View {
    @State private var topBarVM = TopBarViewModel()
    private let pd = PasteDataStore.main

    private var formattedCount: String {
        NumberFormatter.localizedString(
            from: NSNumber(value: pd.filteredCount),
            number: .decimal
        )
    }

    var body: some View {
        HStack {
            Spacer()
            Text("\(formattedCount) 个项目")
                .font(.system(size: 12.0, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .overlay(alignment: .leading) {
            if topBarVM.isPaused {
                CompactPauseIndicator(topBarVM: topBarVM)
            }
        }
        .padding(.horizontal, FloatConst.horizontalPadding)
        .frame(height: FloatConst.footerHeight)
        .frame(maxWidth: .infinity)
        .onAppear {
            topBarVM.startPauseDisplayTimer()
        }
    }
}

// MARK: - 紧凑暂停指示器

private struct CompactPauseIndicator: View {
    var topBarVM: TopBarViewModel

    var body: some View {
        Button {
            topBarVM.resumePasteboard()
        } label: {
            HStack(spacing: Const.space4) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 11.0, weight: .medium))
                    .foregroundStyle(Color.accentColor)

                Text(topBarVM.formattedRemainingTime)
                    .font(.system(size: 11.0, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, Const.space8)
            .padding(.vertical, Const.space4)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .help("点击恢复记录")
    }
}

#Preview {
    FloatingFooterView()
        .frame(width: 350, height: 32)
        .background(Color.gray.opacity(0.1))
}
