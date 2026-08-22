//
//  WelcomePageLayout.swift
//  Clipboard
//

import SwiftUI

struct WelcomePageLayout<Content: View>: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    private let content: Content

    init(
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 30) {
            WelcomePageTitleView(
                title: title,
                subtitle: subtitle
            )
            .frame(width: 520, alignment: .leading)

            content
                .frame(width: 540)
        }
        .padding(.horizontal, WelcomeStyle.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
