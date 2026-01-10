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
    @State private var isExportingLog = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private var logFilePath: String {
        AppLogger.getLogFileURL()?.path ?? "未找到日志文件"
    }

    private var canExportLog: Bool {
        AppLogger.getLogFileURL() != nil
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Const.space16) {
                VStack(alignment: .leading, spacing: 0) {
                    DataStatRow(
                        title: "剪贴板记录数",
                        value: "\(db.totalCount) 条"
                    )
                }
                .padding(.horizontal, Const.space16)
                .settingsStyle()

                Text("应用日志")
                    .font(.headline)
                    .bold()

                VStack(alignment: .leading, spacing: 0) {
                    LogFileRow(
                        logFilePath: logFilePath,
                        isExporting: isExportingLog,
                        canExport: canExportLog
                    ) {
                        exportLog()
                    }
                }
                .padding(.horizontal, Const.space16)
                .settingsStyle()

                Text("数据备份")
                    .font(.headline)
                    .bold()

                VStack(alignment: .leading, spacing: 0) {
                    DataActionRow(
                        title: "备份数据",
                        subtitle: "将所有剪贴板数据导出到文件，可用于迁移或恢复。",
                        buttonTitle: "备份...",
                        isLoading: isExporting
                    ) {
                        exportDatabase()
                    }

                    Divider()

                    DataActionRow(
                        title: "导入数据",
                        subtitle: "从备份文件导入数据，相同记录会自动去重。",
                        buttonTitle: "导入...",
                        isLoading: isImporting
                    ) {
                        importDatabase()
                    }
                }
                .padding(.horizontal, Const.space16)
                .settingsStyle()

                Text("注意事项")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: Const.space4) {
                    Text("• 导入时会根据记录唯一标识自动去重")
                    Text("• 导入的数据不会覆盖现有数据")
                    Text("• 建议定期备份重要数据")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Spacer(minLength: 20)
            }
            .padding(Const.space24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - 导出数据库

    private func exportDatabase() {
        let panel = NSSavePanel()
        panel.title = "导出剪贴板数据"
        panel.nameFieldLabel = "文件名："
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
                    alertTitle = "导出成功"
                    alertMessage = "数据已成功导出"
                } else {
                    log.error("数据库导出失败: \(result.message)")
                    alertTitle = "导出失败"
                    alertMessage = "数据导出失败，请重试"
                }
                showAlert = true
            }
        }
    }

    // MARK: - 导入数据库

    private func importDatabase() {
        let panel = NSOpenPanel()
        panel.title = "导入剪贴板数据"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "sqlite3") ?? .database,
        ]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isImporting = true

        Task.detached(priority: .userInitiated) {
            let result = await PasteSQLManager.manager.importDatabase(from: url)

            await MainActor.run {
                isImporting = false

                if result.success {
                    log.info("数据库导入成功: \(result.message)")
                    alertTitle = "导入成功"
                    alertMessage = result.message

                    Task {
                        await db.resetDefaultList()
                        let count = await PasteSQLManager.manager
                            .getTotalCount()
                        db.totalCount = count
                        db.invalidateTagTypesCache()
                        db.notifyCategoryChipsChanged()
                    }
                } else {
                    log.error("数据库导入失败: \(result.message)")
                    alertTitle = "导入失败"
                    alertMessage = "数据导入失败，请检查文件格式"
                }
                showAlert = true
            }
        }
    }

    // MARK: - 导出日志

    private func exportLog() {
        guard let sourceURL = AppLogger.getLogFileURL() else {
            alertTitle = "导出失败"
            alertMessage = "日志文件未找到"
            showAlert = true
            return
        }

        let panel = NSSavePanel()
        panel.title = "导出日志"
        panel.nameFieldLabel = "文件名："
        panel.nameFieldStringValue = sourceURL.lastPathComponent
        panel.allowedContentTypes = [UTType.log, UTType.plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destURL = panel.url else {
            return
        }

        isExportingLog = true

        Task.detached(priority: .userInitiated) {
            var success = false

            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                success = true
            } catch {
                await MainActor.run {
                    log.error("日志导出失败: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                isExportingLog = false
                if success {
                    log.info("日志导出成功: \(destURL.lastPathComponent)")
                    alertTitle = "导出成功"
                    alertMessage = "日志已成功导出"
                } else {
                    alertTitle = "导出失败"
                    alertMessage = "日志导出失败，请重试"
                }
                showAlert = true
            }
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
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
                BorderedButton(title: buttonTitle, action: action)
            }
        }
        .padding(.vertical, Const.space12)
    }
}

// MARK: - 日志文件行

struct LogFileRow: View {
    let logFilePath: String
    let isExporting: Bool
    let canExport: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Const.space12) {
            VStack(alignment: .leading, spacing: Const.space4) {
                Text("存储路径")
                    .font(.callout)
                Button(logFilePath) {
                    showLogFileInFinder()
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            if canExport {
                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    BorderedButton(title: "导出...", action: action)
                }
            }
        }
        .padding(.vertical, Const.space12)
    }

    private func showLogFileInFinder() {
        guard let logURL = AppLogger.getLogFileURL() else { return }
        NSWorkspace.shared.selectFile(logURL.path, inFileViewerRootedAtPath: "")
    }
}

#Preview {
    StorageSettingView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
