import AppKit
import Foundation
import SQLite

// MARK: - 数据导入导出

extension PasteSQLManager {
    private static let metaTable = "clip_meta"
    private static let metaChipsKey = "user_chips"

    private nonisolated static func localize(
        _ key: String,
        _ arguments: CVarArg...
    ) -> String {
        let format = Bundle.main.localizedString(
            forKey: key,
            value: key,
            table: "Localizable"
        )
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: .current, arguments: arguments)
    }

    nonisolated func exportDatabase(to destinationURL: URL, userChipsData: Data?) async -> ImportExportResult {
        let sourcePath = Self.databasePath

        return await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: sourcePath) else {
                return ImportExportResult(
                    success: false,
                    message: Self.localize("noSourceDb")
                )
            }

            do {
                let sourceDb = try Connection(sourcePath)
                try sourceDb.execute("PRAGMA wal_checkpoint(TRUNCATE)")

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                try FileManager.default.copyItem(
                    atPath: sourcePath,
                    toPath: destinationURL.path
                )

                if let data = userChipsData, let json = String(data: data, encoding: .utf8) {
                    let destDb = try Connection(destinationURL.path)
                    try destDb.execute(
                        "CREATE TABLE IF NOT EXISTS \(Self.metaTable) (key TEXT PRIMARY KEY, value TEXT NOT NULL)"
                    )
                    try destDb.run(
                        "INSERT OR REPLACE INTO \(Self.metaTable) (key, value) VALUES (?, ?)",
                        [Self.metaChipsKey, json]
                    )
                }

                return ImportExportResult(
                    success: true,
                    message: Self.localize("exportSuccess")
                )
            } catch {
                return ImportExportResult(
                    success: false,
                    message: Self.localize("exportFail", error.localizedDescription)
                )
            }
        }.value
    }

    nonisolated func importDatabase(from sourceURL: URL) async -> ImportExportResult {
        let validationResult = await validateImportDatabase(at: sourceURL)
        guard validationResult.success else {
            return validationResult
        }

        let destPath = Self.databasePath

        let result = await Task.detached(priority: .userInitiated) {
            do {
                let sourceDb = try Connection(sourceURL.path, readonly: true)
                let chipsData = Self.readChips(from: sourceDb)
                let categories = await MainActor.run {
                    CategoryChipStore.shared.reserveImport(from: chipsData)
                }
                let result = await Self.importRows(from: sourceURL, to: destPath, categories: categories)
                await MainActor.run {
                    CategoryChipStore.shared.finishImport(categories, data: result.importedChipsData)
                }
                return result
            } catch {
                return ImportExportResult(
                    success: false,
                    message: Self.localize("importFailDetail", error.localizedDescription)
                )
            }
        }.value

        if result.success {
            await MainActor.run {
                PasteMetadataCache.shared.invalidateAllCaches()
            }
        }

        return result
    }

    private nonisolated static func importRows(
        from source: URL, to destination: String, categories: ImportedCategories
    ) async -> ImportExportResult {
        do {
            let sourceDb = try Connection(source.path, readonly: true)
            let destDb = try Connection(destination)

            let sourceTable = Table("Clip")
            let columns = try sourceDb.prepare("PRAGMA table_info(Clip)")
                .compactMap { $0[1] as? String }
            let sourceOrder = columns.contains("sort_order") ? Col.sortOrder : Col.timestamp
            let rows = try sourceDb.prepare(sourceTable.order(sourceOrder.desc, Col.id.desc))

            var importedCount = 0
            var skippedCount = 0
            var importedGroups: Set<Int> = []
            var appInfoDict: [String: String] = [:]
            var importedChipsData: Data?

            try destDb.run("BEGIN TRANSACTION")
            do {
                for row in rows {
                    guard !Task.isCancelled else {
                        throw NSError(domain: "ImportCancelled", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: Self.localize("importCancelled")]
                        )
                    }

                    let sourceGroup = (try? row.get(Col.group)) ?? -1
                    let group = categories.groupIDs[sourceGroup] ?? -1
                    guard let app = try await importRow(row, into: destDb, group: group) else {
                        skippedCount += 1
                        continue
                    }
                    importedCount += 1
                    importedGroups.insert(group)

                    if !app.name.isEmpty, appInfoDict[app.name] == nil {
                        appInfoDict[app.name] = app.path
                    }
                }
                let chips = categories.chips.filter { importedGroups.contains($0.id) }
                importedChipsData = try JSONEncoder().encode(chips)
                try destDb.run("COMMIT")
            } catch {
                _ = try? destDb.run("ROLLBACK")
                throw error
            }

            return importResult(
                imported: importedCount, skipped: skippedCount,
                appInfo: appInfoDict, chipsData: importedChipsData
            )
        } catch {
            return ImportExportResult(
                success: false,
                message: Self.localize("importFailDetail", error.localizedDescription)
            )
        }
    }

    private nonisolated static func importResult(
        imported: Int, skipped: Int, appInfo: [String: String], chipsData: Data?
    ) -> ImportExportResult {
        let skippedText = skipped > 0 ? Self.localize("importSkip", skipped) : ""
        return ImportExportResult(
            success: true,
            message: Self.localize("importResult", imported, skippedText),
            importedAppInfo: appInfo.map { (name: $0.key, path: $0.value) },
            importedChipsData: chipsData
        )
    }

    private nonisolated static func importRow(_ row: Row, into database: Connection, group: Int) async throws
        -> (name: String, path: String)? {
        let destTable = Table("Clip")
        let typeRaw = try row.get(Col.type)
        let data = try row.get(Col.data)
        let uniqueId = await PasteboardModel.generateUniqueId(
            for: PasteboardType(typeRaw),
            data: data
        )
        let existingQuery = destTable.filter(Col.uniqueId == uniqueId)
        let existingCount = try database.scalar(existingQuery.count)

        guard existingCount == 0 else { return nil }

        let appPath = try row.get(Col.appPath)
        let appName = try row.get(Col.appName)
        // 备份按显示顺序依次追加，保留现有记录的位置
        let importSortOrder = SQLite.Expression<Int64>(
            literal: "(SELECT COALESCE(MIN(sort_order), 0) - 1 FROM Clip)"
        )

        let insert = try destTable.insert(
            Col.uniqueId <- uniqueId,
            Col.type <- typeRaw,
            Col.data <- data,
            Col.showData <- row.get(Col.showData),
            Col.timestamp <- row.get(Col.timestamp),
            Col.sortOrder <- importSortOrder,
            Col.appPath <- appPath,
            Col.appName <- appName,
            Col.searchText <- row.get(Col.searchText),
            Col.length <- row.get(Col.length),
            Col.group <- group,
            Col.tag <- try? row.get(Col.tag)
        )

        try database.run(insert)
        return (appName, appPath)
    }

    private nonisolated static func readChips(from database: Connection) -> Data? {
        let metaExists = (try? database.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='\(metaTable)'"
        ) as? Int64) ?? 0
        guard metaExists > 0,
              let rows = try? database.prepare(
                  "SELECT value FROM \(metaTable) WHERE key='\(metaChipsKey)'"
              ) else { return nil }
        for row in rows {
            return (row[0] as? String)?.data(using: .utf8)
        }
        return nil
    }

    private nonisolated func validateImportDatabase(at url: URL) async -> ImportExportResult {
        await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                return ImportExportResult(
                    success: false,
                    message: Self.localize("noFile")
                )
            }

            do {
                let sourceDb = try Connection(url.path, readonly: true)

                let tableExists = try sourceDb.scalar(
                    "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='Clip'"
                ) as? Int64 ?? 0

                guard tableExists > 0 else {
                    return ImportExportResult(
                        success: false,
                        message: Self.localize("backupInvalid", Self.localize("missingTable"))
                    )
                }

                let requiredColumns = [
                    "unique_id", "type", "data", "timestamp",
                    "app_path", "app_name", "search_text", "length"
                ]

                let tableInfo = try sourceDb.prepare("PRAGMA table_info(Clip)")
                var existingColumns: Set<String> = []

                for row in tableInfo {
                    if let columnName = row[1] as? String {
                        existingColumns.insert(columnName)
                    }
                }

                for column in requiredColumns {
                    guard existingColumns.contains(column) else {
                        return ImportExportResult(
                            success: false,
                            message: Self.localize(
                                "backupInvalid",
                                Self.localize("missingColumn", column)
                            )
                        )
                    }
                }

                return ImportExportResult(success: true, message: Self.localize("backupValid"))
            } catch {
                return ImportExportResult(
                    success: false,
                    message: Self.localize("backupInvalid", Self.localize("backupReadFail"))
                )
            }
        }.value
    }
}
