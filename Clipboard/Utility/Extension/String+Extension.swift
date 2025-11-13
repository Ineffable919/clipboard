//
//  String+Extension.swift
//  Clipboard
//
//  Created by crown on 2025/10/5.
//

import Foundation

extension String {
    
    func isCompleteURL() -> Bool {
        guard let url = URL(string: self.trimmingCharacters(in: .whitespacesAndNewlines)) else {
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
        
        let trimmedString = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.absoluteString == trimmedString
    }
    
    func asCompleteURL() -> URL? {
        guard isCompleteURL() else { return nil }
        return URL(string: self.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func isLink() -> Bool {
        return isCompleteURL()
    }
    
    func detectLinks() -> [URL] {
        if let url = asCompleteURL() {
            return [url]
        }
        return []
    }
}
