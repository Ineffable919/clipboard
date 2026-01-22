//
//  View+Extension.swift
//  Clipboard
//
//  Created by crown on 2025/12/06.
//

import Combine
import SwiftUI

// MARK: - Settings Style Modifier

struct SettingsStyleModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Const.settingsRadius)
                    .fill(
                        colorScheme == .light
                            ? Const.lightBackground : Const.darkBackground
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Const.settingsRadius)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
    }
}

struct TextCardStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textSelection(.disabled)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(
                .init(
                    top: Const.space8,
                    leading: Const.space10,
                    bottom: 0.0,
                    trailing: Const.space8
                )
            )
            .frame(
                maxWidth: Const.cardSize,
                maxHeight: Const.cntSize,
                alignment: .topLeading
            )
    }
}

struct AutoScrollOnIMEInputModifier: ViewModifier {
    let onIMEInput: () -> Void

    private let imePublisher =
        NotificationCenter.default.publisher(
            for: NSTextView.didChangeSelectionNotification
        )
        .compactMap { notification -> NSTextView? in
            notification.object as? NSTextView
        }
        .filter { textView in
            let range = textView.markedRange()
            return range.location != NSNotFound && range.length > 0
        }
        .throttle(
            for: .milliseconds(50),
            scheduler: RunLoop.main,
            latest: true
        )

    func body(content: Content) -> some View {
        content
            .onReceive(imePublisher) { _ in
                onIMEInput()
            }
    }
}

extension View {
    func settingsStyle() -> some View {
        modifier(SettingsStyleModifier())
    }

    func textCardStyle() -> some View {
        modifier(TextCardStyleModifier())
    }

    @ViewBuilder
    func autoScrollOnIMEInput(
        perform action: @escaping () -> Void
    ) -> some View {
        modifier(AutoScrollOnIMEInputModifier(onIMEInput: action))
    }
}
