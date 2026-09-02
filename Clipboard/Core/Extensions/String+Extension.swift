//
//  String+Extension.swift
//  Clipboard
//
//  Created by crown on 2025/10/5.
//

import Foundation
import NaturalLanguage

extension String {
    static let regex =
        "^#([A-Fa-f0-9]{3}|[A-Fa-f0-9]{4}|[A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$"

    func isCompleteURL() -> Bool {
        validURLString() != nil
    }

    func asCompleteURL() -> URL? {
        guard let candidate = validURLString() else { return nil }
        return URL(string: candidate)
    }

    func isLink() -> Bool {
        isCompleteURL()
    }

    private func validURLString() -> String? {
        let candidate = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }
        guard !candidate.unicodeScalars.contains(where: {
            CharacterSet.whitespacesAndNewlines.contains($0)
                || CharacterSet.controlCharacters.contains($0)
        }) else {
            return nil
        }

        guard let url = URL(string: candidate) else { return nil }

        guard let scheme = url.scheme?.lowercased() else {
            return nil
        }

        let validSchemes = ["http", "https", "ftp", "ftps"]
        guard validSchemes.contains(scheme) else {
            return nil
        }

        guard let host = url.host else {
            return nil
        }

        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty else {
            return nil
        }

        let hasValidHostFormat =
            cleanHost.contains(".")
                || cleanHost.localizedStandardContains("localhost")
        guard hasValidHostFormat else {
            return nil
        }

        return candidate
    }

    func detectLinks() -> [URL] {
        if let url = asCompleteURL() {
            return [url]
        }

        guard
            let detector = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType.link.rawValue
            )
        else {
            return []
        }

        let matches = detector.matches(
            in: self,
            range: NSRange(startIndex..., in: self)
        )
        return matches.compactMap { match in
            guard let range = Range(match.range, in: self),
                  let url = match.url
            else {
                return nil
            }

            let urlString = String(self[range])
            return urlString.isCompleteURL() ? url : nil
        }
    }

    var isCSSHexColor: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard self == trimmed, !trimmed.isEmpty, trimmed.count <= 50 else {
            return false
        }

        let lowercased = trimmed.lowercased()

        return isValidHexColor(lowercased)
            || Self.cssNamedColors.contains(lowercased)
            || isValidRGBColor(lowercased)
            || isValidHSLColor(lowercased)
    }

    private static let cssNamedColors: Set<String> = [
        "black", "white", "red", "green", "blue", "yellow", "cyan", "magenta",
        "gray", "grey", "silver", "maroon", "olive", "lime", "aqua", "teal",
        "navy", "fuchsia", "purple", "orange", "pink", "brown", "gold",
        "indigo", "violet", "tan", "beige", "coral", "crimson", "khaki",
        "lavender", "salmon", "turquoise", "ivory", "azure", "snow", "mint",
        "transparent"
    ]

    private static let hexCharacters = CharacterSet(charactersIn: "0123456789abcdef")

    private static let hexDigitsOnly = CharacterSet(charactersIn: "0123456789")

    private static let rgbRegex = try? NSRegularExpression(
        pattern: #"^rgba?\((\d+),(\d+),(\d+)(,(0|1|0?\.\d+))?\)$"#
    )

    private static let hslRegex = try? NSRegularExpression(
        pattern: #"^hsla?\((\d+),(\d+)%,(\d+)%(,(0|1|0?\.\d+))?\)$"#
    )

    private func isValidHexColor(_ str: String) -> Bool {
        let hasHash = str.hasPrefix("#")
        let hex = hasHash ? str.dropFirst() : str[...]
        guard [3, 4, 6, 8].contains(hex.count) else { return false }
        guard hex.unicodeScalars.allSatisfy({ Self.hexCharacters.contains($0) }) else { return false }
        if hex.unicodeScalars.allSatisfy({ Self.hexDigitsOnly.contains($0) }),
           !hasHash || hex.count != 6 {
            return false
        }
        return true
    }

    private func isValidRGBColor(_ str: String) -> Bool {
        let clean = str.replacing(" ", with: "")
        guard let regex = Self.rgbRegex else { return false }

        let range = NSRange(clean.startIndex..., in: clean)
        guard let match = regex.firstMatch(in: clean, range: range) else { return false }

        for index in 1 ... 3 {
            guard let range = Range(match.range(at: index), in: clean),
                  let value = Int(clean[range]),
                  value <= 255 else { return false }
        }
        return true
    }

    private func isValidHSLColor(_ str: String) -> Bool {
        let clean = str.replacing(" ", with: "")
        guard let regex = Self.hslRegex else { return false }

        let range = NSRange(clean.startIndex..., in: clean)
        guard let match = regex.firstMatch(in: clean, range: range) else { return false }

        guard let hueRange = Range(match.range(at: 1), in: clean),
              let hue = Int(clean[hueRange]),
              hue <= 360 else { return false }

        for index in 2 ... 3 {
            guard let range = Range(match.range(at: index), in: clean),
                  let value = Int(clean[range]),
                  value <= 100 else { return false }
        }
        return true
    }

    func trimmingTrailingNewlines() -> String {
        var endIndex = endIndex
        while endIndex > startIndex {
            let prevIndex = index(before: endIndex)
            let char = self[prevIndex]
            if char == "\n" || char == "\r" {
                endIndex = prevIndex
            } else {
                break
            }
        }
        return String(self[startIndex ..< endIndex])
    }

    var wordCount: Int {
        var count = 0
        enumerateSubstrings(
            in: startIndex ..< endIndex,
            options: .byWords
        ) { _, _, _, _ in
            count += 1
        }
        return count
    }

    nonisolated var smartWordCount: Int {
        var count = 0

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = self

        tokenizer.enumerateTokens(in: startIndex ..< endIndex) { range, _ in
            let token = self[range]

            // CJK：逐字符
            if token.unicodeScalars.allSatisfy({
                CharacterSet.cjkUnifiedIdeographs.contains($0)
            }) {
                count += token.count
            } else {
                count += 1
            }
            return true
        }
        return count
    }
}

extension CharacterSet {
    nonisolated static let cjkUnifiedIdeographs =
        CharacterSet(charactersIn: "\u{4E00}" ... "\u{9FFF}")
}

// MARK: - Localized Prefix Matching

extension String {
    func localizedStandardHasPrefix(_ prefix: String) -> Bool {
        range(
            of: prefix,
            options: [.caseInsensitive, .diacriticInsensitive, .anchored],
            locale: .current
        ) != nil
    }
}
