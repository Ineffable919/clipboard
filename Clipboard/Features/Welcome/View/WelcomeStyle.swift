//
//  WelcomeStyle.swift
//  Clipboard
//

import SwiftUI

enum WelcomeStyle {
    static let windowWidth: CGFloat = 720.0
    static let windowHeight: CGFloat = 500.0
    static let horizontalPadding: CGFloat = 50.0
    static let leftColumnWidth: CGFloat = 270.0
    static let rightColumnWidth: CGFloat = 304.0
    static let columnSpacing: CGFloat = 46.0

    static let accent = Color(nsColor: .systemBlue)
    static let border = Color.primary.opacity(0.18)

    static func background(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            .white
        case .dark:
            Color(
                red: 37.0 / 255.0,
                green: 39.0 / 255.0,
                blue: 43.0 / 255.0
            )
        @unknown default:
            .white
        }
    }

    static func primaryText(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            Color(
                red: 29.0 / 255.0,
                green: 29.0 / 255.0,
                blue: 31.0 / 255.0
            )
        case .dark:
            Color(
                red: 245.0 / 255.0,
                green: 247.0 / 255.0,
                blue: 250.0 / 255.0
            )
        @unknown default:
            .primary
        }
    }

    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            Color(
                red: 110.0 / 255.0,
                green: 110.0 / 255.0,
                blue: 115.0 / 255.0
            )
        case .dark:
            Color(
                red: 198.0 / 255.0,
                green: 202.0 / 255.0,
                blue: 210.0 / 255.0
            )
        @unknown default:
            .secondary
        }
    }

    static func tertiaryText(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            Color(
                red: 154.0 / 255.0,
                green: 154.0 / 255.0,
                blue: 160.0 / 255.0
            )
        case .dark:
            Color(
                red: 146.0 / 255.0,
                green: 152.0 / 255.0,
                blue: 163.0 / 255.0
            )
        @unknown default:
            Color(nsColor: .tertiaryLabelColor)
        }
    }
}
