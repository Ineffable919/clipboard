//
//  WelcomeSampleCardView.swift
//  Clipboard
//

import SwiftUI

struct WelcomeSampleCardView: View {
    enum Kind {
        case code
        case link
        case note
        case color

        var timestamp: String {
            switch self {
            case .code: "09:41"
            case .link: "09:38"
            case .note: "09:36"
            case .color: "09:33"
            }
        }

        var width: CGFloat {
            switch self {
            case .code, .link, .note: 135
            case .color: 92
            }
        }
    }

    let kind: Kind
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                sourceIcon

                Text(verbatim: kind.timestamp)
                    .font(.system(size: 7.5, weight: .medium))

                Spacer(minLength: 0)

                Image(systemName: "ellipsis")
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundStyle(WelcomeStyle.primaryText(for: colorScheme))
            .padding(.horizontal, 6)
            .frame(height: 29)

            cardContent
                .padding(.horizontal, 6)
                .padding(.bottom, 7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: kind.width, height: 146)
        .background(WelcomeStyle.surface(for: colorScheme))
        .clipShape(.rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected ? WelcomeStyle.accent : WelcomeStyle.border,
                    lineWidth: isSelected ? 1.5 : 0.75
                )
        }
        .shadow(
            color: WelcomeStyle.panelShadow(for: colorScheme),
            radius: 4,
            y: 2
        )
    }

    @ViewBuilder
    private var sourceIcon: some View {
        switch kind {
        case .code:
            Image(systemName: "swift")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(nsColor: .systemOrange))
                .frame(width: 17, height: 17)
                .background(
                    WelcomeStyle.subtleSurface(for: colorScheme),
                    in: .rect(cornerRadius: 5)
                )
        case .link:
            Image(systemName: "safari")
                .font(.system(size: 12))
                .foregroundStyle(WelcomeStyle.accent)
                .frame(width: 17, height: 17)
                .background(
                    WelcomeStyle.subtleSurface(for: colorScheme),
                    in: .circle
                )
        case .note:
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(WelcomeStyle.surface(for: colorScheme))

                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 4
                )
                .fill(Color(nsColor: .systemYellow))
                .frame(height: 5)
            }
            .frame(width: 17, height: 17)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(WelcomeStyle.border, lineWidth: 0.5)
            }
        case .color:
            WelcomeFigmaIconView()
                .frame(width: 17, height: 17)
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        switch kind {
        case .code:
            WelcomeSwiftCodeView(
                plainText: WelcomeStyle.primaryText(for: colorScheme)
            )
        case .link:
            linkContent
        case .note:
            noteContent
        case .color:
            colorContent
        }
    }

    private var linkContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(WelcomeStyle.subtleSurface(for: colorScheme))

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .systemTeal),
                                Color(nsColor: .systemGreen)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 37, height: 37)
                    .offset(x: -10, y: 1)

                Image(systemName: "triangle.fill")
                    .resizable()
                    .foregroundStyle(WelcomeStyle.accent)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 40, height: 39)
                    .offset(x: 13, y: 1)
            }
            .frame(height: 55)

            Text(.welcomeSampleLinkTitle)
                .font(.system(size: 8.5, weight: .medium))
                .lineSpacing(0.5)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: "clipapp.com")
                .font(.system(size: 7.5))
                .foregroundStyle(WelcomeStyle.tertiaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var noteContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(.welcomeSampleNoteTitle)
                .font(.system(size: 9, weight: .medium))

            VStack(alignment: .leading, spacing: 6) {
                noteRow(.welcomeSampleNoteOne)
                noteRow(.welcomeSampleNoteTwo)
                noteRow(.welcomeSampleNoteThree)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var colorContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 7)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(
                                red: 13.0 / 255.0,
                                green: 206.0 / 255.0,
                                blue: 190.0 / 255.0
                            ),
                            Color(
                                red: 14.0 / 255.0,
                                green: 165.0 / 255.0,
                                blue: 233.0 / 255.0
                            ),
                            Color(
                                red: 15.0 / 255.0,
                                green: 105.0 / 255.0,
                                blue: 235.0 / 255.0
                            )
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 80)

            HStack(alignment: .bottom, spacing: 2) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "#0EA5E9")
                        .font(.system(size: 8, weight: .medium, design: .rounded))

                    Text(.welcomeSampleColorName)
                        .font(.system(size: 6.5))
                        .foregroundStyle(
                            WelcomeStyle.secondaryText(for: colorScheme)
                        )
                }

                Spacer(minLength: 0)

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 7.5))
                    .foregroundStyle(
                        WelcomeStyle.secondaryText(for: colorScheme)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func noteRow(_ title: LocalizedStringResource) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Circle()
                .fill(WelcomeStyle.primaryText(for: colorScheme))
                .frame(width: 2, height: 2)

            Text(title)
                .font(.system(size: 7.5))
                .lineLimit(1)
        }
    }
}

private struct WelcomeSwiftCodeView: View {
    let plainText: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1.7) {
            codeLine([
                ("struct ", WelcomeSwiftSyntaxColor.keyword),
                ("ContentView", WelcomeSwiftSyntaxColor.type),
                (": ", plainText),
                ("View", WelcomeSwiftSyntaxColor.member),
                (" {", plainText)
            ])
            codeLine([
                ("var ", WelcomeSwiftSyntaxColor.keyword),
                ("body", WelcomeSwiftSyntaxColor.type),
                (": ", plainText),
                ("some ", WelcomeSwiftSyntaxColor.keyword),
                ("View", WelcomeSwiftSyntaxColor.member),
                (" {", plainText)
            ], indent: 7)
            codeLine([
                ("VStack", WelcomeSwiftSyntaxColor.type),
                (" {", plainText)
            ], indent: 13)
            codeLine([
                ("Image", WelcomeSwiftSyntaxColor.type),
                ("(systemName: ", plainText),
                ("\"bolt.fill\"", WelcomeSwiftSyntaxColor.string),
                (")", plainText)
            ], indent: 20)
            codeLine([
                (".font", WelcomeSwiftSyntaxColor.type),
                ("(", plainText),
                (".largeTitle", WelcomeSwiftSyntaxColor.member),
                (")", plainText)
            ], indent: 27)
            codeLine([
                (".foregroundStyle", plainText),
                ("(", plainText),
                (".blue", WelcomeSwiftSyntaxColor.member),
                (")", plainText)
            ], indent: 27)
            codeLine([
                ("Text", WelcomeSwiftSyntaxColor.type),
                ("(", plainText),
                ("\"Clip is fast.\"", WelcomeSwiftSyntaxColor.string),
                (")", plainText)
            ], indent: 20)
            codeLine([
                (".font", WelcomeSwiftSyntaxColor.type),
                ("(", plainText),
                (".title2", WelcomeSwiftSyntaxColor.member),
                (")", plainText)
            ], indent: 27)
            codeLine([("}", plainText)], indent: 13)
            codeLine([
                (".padding", WelcomeSwiftSyntaxColor.member),
                ("()", plainText)
            ], indent: 13)
            codeLine([("}", plainText)], indent: 7)
            codeLine([("}", plainText)])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func codeLine(
        _ segments: [(String, Color)],
        indent: CGFloat = 0
    ) -> some View {
        Text(attributedCode(segments))
            .font(.system(size: 5.2, weight: .medium, design: .monospaced))
            .lineLimit(1)
            .padding(.leading, indent)
    }

    private func attributedCode(
        _ segments: [(String, Color)]
    ) -> AttributedString {
        var result = AttributedString()
        for (text, color) in segments {
            var segment = AttributedString(text)
            segment.foregroundColor = color
            result.append(segment)
        }
        return result
    }
}

private enum WelcomeSwiftSyntaxColor {
    static let keyword = Color(
        red: 236.0 / 255.0,
        green: 72.0 / 255.0,
        blue: 153.0 / 255.0
    )
    static let type = Color(
        red: 59.0 / 255.0,
        green: 130.0 / 255.0,
        blue: 246.0 / 255.0
    )
    static let member = Color(
        red: 139.0 / 255.0,
        green: 92.0 / 255.0,
        blue: 246.0 / 255.0
    )
    static let string = Color(
        red: 242.0 / 255.0,
        green: 90.0 / 255.0,
        blue: 61.0 / 255.0
    )
}

private struct WelcomeFigmaIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(.black)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    iconCircle(.red)
                    iconCircle(.orange)
                }

                HStack(spacing: 0) {
                    iconCircle(.purple)
                    iconCircle(.blue)
                }

                HStack(spacing: 0) {
                    iconCircle(.green)
                    Color.clear.frame(width: 4.5, height: 4.5)
                }
            }
        }
    }

    private func iconCircle(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 4.5, height: 4.5)
    }
}
