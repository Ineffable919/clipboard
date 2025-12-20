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
        let digest = SHA256.hash(data: self)
        return digest.reduce(into: "") { result, byte in
            result += String(format: "%02hhx", byte)
        }
    }

    var sha256Data: Data {
        Data(SHA256.hash(data: self))
    }
}
