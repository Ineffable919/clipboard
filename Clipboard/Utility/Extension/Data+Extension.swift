//
//  Data+Extension.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import CryptoKit
import SwiftUI

extension Data {
    var sha256Hex: String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }

    var sha256Data: Data {
        Data(SHA256.hash(data: self))
    }
}
