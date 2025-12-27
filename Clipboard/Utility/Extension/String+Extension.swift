//
//  String+Extension.swift
//  Clipboard
//
//  Created by crown on 2025/10/5.
//

import Foundation

extension String {
    static let regex =
        "^#([A-Fa-f0-9]{3}|[A-Fa-f0-9]{4}|[A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$"

    func isCompleteURL() -> Bool {
        let trimmedString = trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedString.isEmpty else {
            return false
        }

        guard let url = URL(string: trimmedString) else {
            return false
        }

        guard let scheme = url.scheme?.lowercased() else {
            return false
        }

        let validSchemes = ["http", "https", "ftp", "ftps"]
        guard validSchemes.contains(scheme) else {
            return false
        }

        guard let host = url.host else {
            return false
        }

        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty else {
            return false
        }

        let hasValidHostFormat = cleanHost.contains(".") || cleanHost.localizedStandardContains("localhost")
        guard hasValidHostFormat else {
            return false
        }

        return url.absoluteString == trimmedString
    }

    func asCompleteURL() -> URL? {
        guard isCompleteURL() else { return nil }
        return URL(string: trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func isLink() -> Bool {
        isCompleteURL()
    }

    func detectLinks() -> [URL] {
        if let url = asCompleteURL() {
            return [url]
        }

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let matches = detector.matches(in: self, range: NSRange(startIndex..., in: self))
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
        let predicate = NSPredicate(format: "SELF MATCHES %@", String.regex)
        return predicate.evaluate(with: self)
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
}
