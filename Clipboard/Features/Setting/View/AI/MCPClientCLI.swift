//
//  MCPClientCLI.swift
//  Clipboard
//
//  Created by crown on 2026/11/18
//

import AppKit

// MARK: - MCPClientCLI

/// 调用客户端 App 包内自带的命令行完成添加，不依赖用户把命令装进 PATH
nonisolated struct MCPClientCLI: Sendable {
    /// 按优先级排列，取第一个已安装的
    let bundleIDs: [String]
    /// 相对 App 包根目录的可执行文件路径
    let path: String
    let arguments: [String]

    @MainActor
    var executable: URL? {
        for id in bundleIDs {
            guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { continue }
            let url = app.appending(path: path)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    /// 运行命令，非零退出时抛出带 stderr 内容的错误
    func run(_ executable: URL) async throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice
        let errorHandle = errorPipe.fileHandleForReading

        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }

        guard status == 0 else {
            let data = (try? errorHandle.readToEnd()) ?? Data()
            let message = (String(bytes: data, encoding: .utf8) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw MCPClientCLIError(message: message.isEmpty ? "exit \(status)" : message)
        }
    }
}

// MARK: - MCPClientCLIError

nonisolated struct MCPClientCLIError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
