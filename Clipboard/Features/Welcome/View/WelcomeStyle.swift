//
//  WelcomeStyle.swift
//  Clipboard
//

import SwiftUI

enum WelcomeStyle {
    static let windowWidth: CGFloat = 720.0
    static let windowHeight: CGFloat = 500.0
    static let horizontalPadding: CGFloat = 48.0
    static let footerHeight: CGFloat = 66.0

    static let accent = Color(nsColor: .systemBlue)
    static let border = Color.primary.opacity(0.18)

    static func background(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            Color(
                red: 245.0 / 255.0,
                green: 245.0 / 255.0,
                blue: 247.0 / 255.0
            )
        case .dark:
            Color(
                red: 24.0 / 255.0,
                green: 25.0 / 255.0,
                blue: 28.0 / 255.0
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

    static func surface(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            .white
        case .dark:
            Color(
                red: 42.0 / 255.0,
                green: 44.0 / 255.0,
                blue: 49.0 / 255.0
            )
        @unknown default:
            Color(nsColor: .controlBackgroundColor)
        }
    }

    static func subtleSurface(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            Color.black.opacity(0.045)
        case .dark:
            Color.white.opacity(0.08)
        @unknown default:
            Color.primary.opacity(0.06)
        }
    }

    static func panelShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light
            ? Color.black.opacity(0.09)
            : Color.black.opacity(0.3)
    }
}
