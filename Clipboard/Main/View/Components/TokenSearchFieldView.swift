//
//  TokenSearchFieldView.swift
//  Clipboard
//
//  Created by crown on 2026/02/04.
//

import AppKit
import SwiftUI

struct TokenSearchFieldView: View {
    @State private var tokens: [TokenItem] = TokenSearchFieldView.sampleTokens()
    @State private var query: String = ""
    @State private var isFocused = true

    private let suggestions = TokenSearchFieldView.sampleSuggestions()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TokenSearchFieldBar(
                tokens: $tokens,
                query: $query,
                suggestions: suggestions,
                isFocused: $isFocused
            )
            .frame(width: 420)
            .padding(.top, 12)

            Spacer()
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.03),
                    Color.primary.opacity(0.01),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private static func sampleTokens() -> [TokenItem] {
        let icon = NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: nil
        )
        if let icon {
            return [TokenItem(label: "Kiro", icon: icon)]
        }
        return []
    }

    private static func sampleSuggestions() -> [TokenSuggestion] {
        let appIcon = NSImage(
            systemSymbolName: "app",
            accessibilityDescription: nil
        )
        let docIcon = NSImage(
            systemSymbolName: "doc.text",
            accessibilityDescription: nil
        )
        let calendarIcon = NSImage(
            systemSymbolName: "calendar",
            accessibilityDescription: nil
        )

        return [
            TokenSuggestion(label: "Kiro", icon: appIcon),
            TokenSuggestion(label: "Safari", icon: appIcon),
            TokenSuggestion(label: "Terminal", icon: appIcon),
            TokenSuggestion(label: "Text", icon: docIcon),
            TokenSuggestion(label: "Today", icon: calendarIcon),
        ]
    }
}

private struct TokenSearchFieldBar: View {
    @Binding var tokens: [TokenItem]
    @Binding var query: String
    let suggestions: [TokenSuggestion]
    @Binding var isFocused: Bool
    @State private var hoveredSuggestionID: UUID?

    private let barCornerRadius: CGFloat = 18
    private let barHeight: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)

                TokenSearchField(
                    tokens: $tokens,
                    query: $query,
                    suggestions: suggestions,
                    isFocused: isFocused,
                    onFocusChange: { focused in
                        isFocused = focused
                    },
                    onTokenInserted: { _ in },
                    onTokenRemoved: { _ in }
                )
                .frame(maxWidth: .infinity, minHeight: 22)
                .layoutPriority(1)
                .overlay(alignment: .leading) {
                    if tokens.isEmpty, query.isEmpty {
                        Text("Search")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: barHeight)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(0.06),
                                Color.primary.opacity(0.02),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                    .stroke(
                        isFocused ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.2),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
            .clipShape(.rect(cornerRadius: barCornerRadius))

            if shouldShowSuggestions {
                VStack(spacing: 4) {
                    ForEach(filteredSuggestions) { suggestion in
                        Button {
                            insertSuggestion(suggestion)
                        } label: {
                            HStack(spacing: 8) {
                                if let icon = suggestion.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "tag")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }

                                Text(suggestion.label)
                                    .font(.callout)
                                    .foregroundStyle(.primary)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        hoveredSuggestionID == suggestion.id
                                            ? Color.primary.opacity(0.08)
                                            : Color.clear
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            hoveredSuggestionID = hovering ? suggestion.id : nil
                        }
                    }
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.primary.opacity(0.06),
                                    Color.primary.opacity(0.02),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
            }
        }
    }

    private var filteredSuggestions: [TokenSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = suggestions.filter { suggestion in
            !tokens.contains(where: { $0.label == suggestion.label })
        }

        if trimmed.isEmpty {
            return Array(base.prefix(6))
        }

        return base.filter { suggestion in
            suggestion.label.localizedStandardContains(trimmed)
        }
        .prefix(6)
        .map(\.self)
    }

    private var shouldShowSuggestions: Bool {
        isFocused && !filteredSuggestions.isEmpty
    }

    private func insertSuggestion(_ suggestion: TokenSuggestion) {
        let icon = suggestion.icon
            ?? NSImage(systemSymbolName: "tag", accessibilityDescription: nil)
        guard let icon else { return }
        let token = TokenItem(label: suggestion.label, icon: icon)
        if !tokens.contains(where: { $0.label == token.label }) {
            tokens.append(token)
        }
        query = ""
    }
}

#Preview {
    TokenSearchFieldView()
        .frame(width: 640, height: 240)
}
