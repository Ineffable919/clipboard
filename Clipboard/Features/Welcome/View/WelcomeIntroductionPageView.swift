//
//  WelcomeIntroductionPageView.swift
//  Clipboard
//

import SwiftUI

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
