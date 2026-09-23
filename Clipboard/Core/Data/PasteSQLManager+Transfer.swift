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

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                let destDb = try Connection(destinationURL.path)
                let backup = try sourceDb.backup(usingConnection: destDb)
                try backup.step()

                if let data = userChipsData, let json = String(data: data, encoding: .utf8) {
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
            do {
                try await loadApps()
                let records = await getDistinctAppInfo()
                await MainActor.run {
                    SourceAppCache.shared.replace(records)
                    SourceAppCache.shared.warmMissingIcons()
                    AppColorService.shared.fillMissingColors()
                    PasteMetadataCache.shared.invalidateAllCaches()
                }
            } catch {
                log.error("导入后刷新应用缓存失败：\(error)")
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
            destDb.busyTimeout = 5.0

            let columns = try sourceDb.prepare("PRAGMA table_info(Clip)")
                .compactMap { $0[1] as? String }
            let sourceOrder = columns.contains("sort_order") ? Col.sortOrder : Col.timestamp
            let rows = try sourceDb.prepare(Table("Clip").order(sourceOrder.desc, Col.id.desc))

            var importedCount = 0
            var skippedCount = 0
            var importedChipsData: Data?

            try destDb.run("BEGIN IMMEDIATE TRANSACTION")
            do {
                let appIDs = try SourceAppSQL.importIDs(
                    from: sourceDb, into: destDb, normalized: columns.contains("app_id")
                )
                for row in rows {
                    guard !Task.isCancelled else {
                        throw NSError(domain: "ImportCancelled", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: Self.localize("importCancelled")]
                        )
                    }

                    let group = categories.groupIDs[(try? row.get(Col.group)) ?? -1] ?? -1
                    let appID = try SourceAppSQL.importID(for: row, mapping: appIDs,
                                                          normalized: columns.contains("app_id"))
                    guard try await importRow(row, into: destDb, group: group, appID: appID) else {
                        skippedCount += 1
                        continue
                    }
                    importedCount += 1
                }
                importedChipsData = try JSONEncoder().encode(categories.chips)
                try SourceAppSQL.reassignMissing(on: destDb, fallback: .current)
                try destDb.run("COMMIT")
            } catch {
                _ = try? destDb.run("ROLLBACK")
                throw error
            }

            return importResult(
                imported: importedCount, skipped: skippedCount,
                chipsData: importedChipsData
            )
        } catch {
            return ImportExportResult(
                success: false,
                message: Self.localize("importFailDetail", error.localizedDescription)
            )
        }
    }

    private nonisolated static func importResult(
        imported: Int, skipped: Int, chipsData: Data?
    ) -> ImportExportResult {
        let skippedText = skipped > 0 ? Self.localize("importSkip", skipped) : ""
        return ImportExportResult(
            success: true,
            message: Self.localize("importResult", imported, skippedText),
            importedChipsData: chipsData
        )
    }

    private nonisolated static func importRow(
        _ row: Row, into database: Connection, group: Int, appID: Int64
    ) async throws -> Bool {
        let destTable = Table("Clip")
        let typeRaw = try row.get(Col.type)
        let data = try row.get(Col.data)
        let uniqueId = await PasteboardModel.generateUniqueId(
            for: PasteboardType(typeRaw),
            data: data
        )
        let existingQuery = destTable.filter(Col.uniqueId == uniqueId)
        let existingCount = try database.scalar(existingQuery.count)

        guard existingCount == 0 else { return false }

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
            Col.appID <- appID,
            Col.searchText <- row.get(Col.searchText),
            Col.length <- row.get(Col.length),
            Col.group <- group,
            Col.hidden <- (try? row.get(Col.hidden)) ?? 0,
            Col.tag <- try? row.get(Col.tag)
        )

        try database.run(insert)
        return true
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
                    "search_text", "length"
                ]

                let existingColumns = Set(try sourceDb.prepare("PRAGMA table_info(Clip)")
                    .compactMap { $0[1] as? String })

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

                if existingColumns.contains("app_id") {
                    // 读取应用表也验证新备份字段完整性；具体引用在导入事务内校验。
                    _ = try sourceDb.prepare("SELECT id, bundle_id, app_name, app_path, icon_data FROM App LIMIT 0")
                } else if !existingColumns.isSuperset(of: ["app_name", "app_path"]) {
                    return ImportExportResult(success: false,
                        message: Self.localize("backupInvalid", Self.localize("missingColumn", "app_id")))
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
