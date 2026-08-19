//
//  WelcomePageLayout.swift
//  Clipboard
//

import SwiftUI

struct WelcomePageLayout<Content: View>: View {
    let step: LocalizedStringResource
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    private let content: Content

    init(
        step: LocalizedStringResource,
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource,
        @ViewBuilder content: () -> Content
    ) {
        self.step = step
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: WelcomeStyle.columnSpacing) {
            WelcomePageTitleView(
                step: step,
                title: title,
                subtitle: subtitle
            )
            .frame(width: WelcomeStyle.leftColumnWidth, alignment: .leading)

            content
                .frame(width: WelcomeStyle.rightColumnWidth)
        }
        .padding(.horizontal, WelcomeStyle.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
