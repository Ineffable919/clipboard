//
//  FloatingFooterView.swift
//  Clipboard
//
//  Created by crown on 2026/1/14.
//

import SwiftUI

struct FloatingFooterView: View {
    private let pd = PasteDataStore.main

    private var formattedCount: String {
        NumberFormatter.localizedString(
            from: NSNumber(value: pd.filteredCount),
            number: .decimal
        )
    }

    var body: some View {
        HStack {
            Text("\(formattedCount) 个项目")
                .font(.system(size: 13.0, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, FloatConst.horizontalPadding)
        .frame(height: FloatConst.footerHeight)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    FloatingFooterView()
        .frame(width: 350, height: 32)
        .background(Color.gray.opacity(0.1))
}
