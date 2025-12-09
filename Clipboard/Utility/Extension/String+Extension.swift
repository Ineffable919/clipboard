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
        guard
            let url = URL(
                string: trimmingCharacters(in: .whitespacesAndNewlines)
            )
        else {
            return false
        }

        guard let scheme = url.scheme?.lowercased() else {
            return false
        }

        let validSchemes = ["http", "https", "ftp", "ftps"]
        guard validSchemes.contains(scheme) else {
            return false
        }

        guard let host = url.host, !host.isEmpty else {
            return false
        }

        let trimmedString = trimmingCharacters(in: .whitespacesAndNewlines)
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
        return []
    }

    var isCSSHexColor: Bool {
        let predicate = NSPredicate(format: "SELF MATCHES %@", String.regex)

        return predicate.evaluate(with: self)
    }
}
