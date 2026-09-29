//
//  WelcomeIntroductionPageView.swift
//  Clipboard
//

import SwiftUI

#Preview {
    WelcomeIntroductionPageView()
        .frame(width: WelcomeStyle.windowWidth, height: WelcomeStyle.windowHeight - WelcomeStyle.footerHeight)
}

struct WelcomeIntroductionPageView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 31) {
            WelcomeIntroductionCopyView()
                .frame(width: 224, alignment: .leading)

            WelcomeWorkflowView()
                .frame(width: 421)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
