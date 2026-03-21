//
//  StorageSettingView.swift
//  Clipboard
//
//  Created by crown on 2026/1/9.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 存储设置视图

struct StorageSettingView: View {
    @Environment(\.colorScheme) var colorScheme

    private var db: PasteDataStore = .main

    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Const.space16) {
                VStack(alignment: .leading, spacing: 0) {
                    DataStatRow(
                        title: String(localized: .settingStorageClipboardItemCount),
                        value: String.localizedStringWithFormat(
                            String(
                                localized: "settingStorageClipboardItemCountValue",
                                defaultValue: "%lld items",
                                table: "Localizable"
                            ),
                            db.totalCount
                        )
                    )
                }
                .padding(.horizontal, Const.space16)
                .settingsStyle()

                Text(.settingStorageBackupSectionTitle)
                    .font(.headline)
                    .bold()

                VStack(alignment: .leading, spacing: 0) {
                    DataActionRow(
                        title: String(localized: .settingStorageExportTitle),
                        subtitle: String(localized: .settingStorageExportDescription),
                        buttonTitle: String(localized: .settingStorageExportButton),
                        isLoading: isExporting
                    ) {
                        exportDatabase()
                    }

                    Divider()

                    DataActionRow(
                        title: String(localized: .settingStorageImportTitle),
                        subtitle: String(localized: .settingStorageImportDescription),
                        buttonTitle: String(localized: .settingStorageImportButton),
                        isLoading: isImporting
                    ) {
                        importDatabase()
                    }
                }
                .padding(.horizontal, Const.space16)
                .settingsStyle()

                Text(.settingStorageNotesTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: Const.space4) {
                    Text(.settingStorageNoteDeduplicate)
                    Text(.settingStorageNotePreserveExistingData)
                    Text(.settingStorageNoteBackupRegularly)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Spacer(minLength: 20)
            }
            .padding(Const.space24)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(alertTitle, isPresented: $showAlert) {
            Button(.commonConfirm, role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - 导出数据库

    private func exportDatabase() {
        let panel = NSSavePanel()
        panel.title = String(localized: .settingStorageExportPanelTitle)
        panel.nameFieldLabel = String(localized: .settingStorageFileNameLabel)
        panel.nameFieldStringValue = "Clip_Backup_\(formattedDate()).sqlite3"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "sqlite3") ?? .database,
        ]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExporting = true

        Task.detached(priority: .userInitiated) {
            let result = await PasteSQLManager.manager.exportDatabase(to: url)

            await MainActor.run {
                isExporting = false
                if result.success {
                    log.info("数据库导出成功: \(url.lastPathComponent)")
                    alertTitle = String(localized: .settingStorageExportSuccessTitle)
                    alertMessage = result.message
                } else {
                    log.error("数据库导出失败: \(result.message)")
                    alertTitle = String(localized: .settingStorageExportFailureTitle)
                    alertMessage = result.message
                }
                showAlert = true
            }
        }
    }

    // MARK: - 导入数据库

    private func importDatabase() {
        let panel = NSOpenPanel()
        panel.title = String(localized: .settingStorageImportPanelTitle)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "sqlite3") ?? .database,
        ]

        let clipDataDir = URL.documentsDirectory.appending(path: "Clip")
        if FileManager.default.fileExists(atPath: clipDataDir.path) {
            panel.directoryURL = clipDataDir
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isImporting = true

        Task.detached(priority: .userInitiated) {
            let result = await PasteSQLManager.manager.importDatabase(from: url)

            await MainActor.run {
                isImporting = false

                if result.success {
                    log.info("数据库导入成功: \(result.message)")
                    alertTitle = String(localized: .settingStorageImportSuccessTitle)
                    alertMessage = result.message

                    Task {
                        await db.resetDefaultList()
                        let count = await PasteSQLManager.manager.getTotalCount()
                        db.totalCount = count
                        db.invalidateTagTypesCache()
                        db.notifyCategoryChipsChanged()
                    }
                } else {
                    log.error("数据库导入失败: \(result.message)")
                    alertTitle = String(localized: .settingStorageImportFailureTitle)
                    alertMessage = result.message.contains(
                        String(localized: .importCancelled)
                    )
                        ? String(localized: .settingStorageImportCancelled)
                        : result.message
                }
                showAlert = true
            }
        }
    }

    private func formattedDate() -> String {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: Date()
        )
        let year = components.year ?? 0
        let month = (components.month ?? 0).formatted(
            .number.precision(.integerLength(2))
        )
        let day = (components.day ?? 0).formatted(
            .number.precision(.integerLength(2))
        )
        return "\(year)\(month)\(day)"
    }
}

// MARK: - 数据统计行

struct DataStatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.callout)
        }
        .padding(.vertical, Const.space12)
    }
}

// MARK: - 数据操作行

struct DataActionRow: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Const.space12) {
            VStack(alignment: .leading, spacing: Const.space4) {
                Text(title)
                    .font(.callout)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                SystemButton(title: buttonTitle, action: action)
            }
        }
        .padding(.vertical, Const.space12)
    }
}

#Preview {
    StorageSettingView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
