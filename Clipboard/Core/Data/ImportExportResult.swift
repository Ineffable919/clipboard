//
//  ImportExportResult.swift
//  Clipboard
//
//  Created by crown on 2026/9/5
//

import Foundation

extension PasteSQLManager {
    struct ImportExportResult {
        let success: Bool
        let message: String
        var importedChipsData: Data?
    }

}
