//
//  Logger.swift
//  clipboard
//
//  Created by wangj on 2025/6/14.
//

import Foundation
import os.log

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = .current
        return formatter
    }()

    static let fileFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()
}

enum LogLevel: String, CaseIterable, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var osLogType: OSLogType {
        switch self {
        case .debug:
            .debug
        case .info:
            .info
        case .warning:
            .default
        case .error:
            .error
        }
    }

    var priority: Int {
        switch self {
        case .debug: 0
        case .info: 1
        case .warning: 2
        case .error: 3
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.priority < rhs.priority
    }
}

class AppLogger {
    static let shared = AppLogger()

    private let osLogger: os.Logger
    private let logQueue = DispatchQueue(label: "com.crown.clipboard.logger", qos: .utility)
    private nonisolated(unsafe) var logFileURL: URL?

    #if DEBUG
        var minimumLogLevel: LogLevel = .debug
    #else
        var minimumLogLevel: LogLevel = .info
    #endif

    private init() {
        osLogger = os.Logger(subsystem: "com.crown.clipboard", category: "AppLogger")
        setupLogFile()
    }

    func debug(
        _ message: String, file: String = #file, function: String = #function, line: Int = #line,
    ) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    func info(
        _ message: String, file: String = #file, function: String = #function, line: Int = #line,
    ) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    func warn(
        _ message: String, file: String = #file, function: String = #function, line: Int = #line,
    ) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    func error(
        _ message: String, file: String = #file, function: String = #function, line: Int = #line,
    ) {
        log(message, level: .error, file: file, function: function, line: line)
    }

    private func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        guard level >= minimumLogLevel else { return }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())

        #if DEBUG
            let consoleMessage = "[\(level.rawValue)] [\(fileName):\(line)] \(message)"
            print("\(timestamp) \(consoleMessage)")
        #else
            let logMessage = "[\(fileName):\(line)] \(function) - \(message)"
            writeToFile(logMessage, level: level)
            if level == .error {
                osLogger.error("\(logMessage)")
            }
        #endif
    }

    private func setupLogFile() {
        #if !DEBUG
            createLogFileURL()
        #endif
    }

    private func createLogFileURL() {
        guard
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask,
            ).first
        else {
            return
        }

        let appDir = appSupport.appendingPathComponent("com.crown.clipboard")
        let logsDir = appDir.appendingPathComponent("logs")

        do {
            try FileManager.default.createDirectory(
                at: logsDir, withIntermediateDirectories: true, attributes: nil,
            )
        } catch {
            osLogger.error("Failed to create logs directory: \(error.localizedDescription)")
            return
        }

        let logFileName = "Clip-\(DateFormatter.fileFormatter.string(from: Date())).log"

        logFileURL = logsDir.appendingPathComponent(logFileName)

        cleanOldLogFiles(in: logsDir)
    }

    private func writeToFile(_ message: String, level: LogLevel) {
        logQueue.async { [weak self] in
            guard let self, let logURL = logFileURL else { return }

            let timestamp = DateFormatter.logFormatter.string(from: Date())
            let logEntry = "[\(timestamp)] [\(level.rawValue)] \(message)\n"

            guard let data = logEntry.data(using: .utf8) else { return }

            if FileManager.default.fileExists(atPath: logURL.path) {
                do {
                    let fileHandle = try FileHandle(forWritingTo: logURL)
                    defer { fileHandle.closeFile() }
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                } catch {
                    osLogger.error(
                        "Failed to write to log file: \(error.localizedDescription)")
                }
            } else {
                do {
                    try data.write(to: logURL)
                } catch {
                    osLogger.error("Failed to create log file: \(error.localizedDescription)")
                }
            }
        }
    }

    private func cleanOldLogFiles(in directory: URL) {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.creationDateKey], options: [],
            )
            let logFiles = files.filter { $0.pathExtension == "log" }

            let calendar = Calendar.current
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

            for file in logFiles {
                if let creationDate = try file.resourceValues(forKeys: [.creationDateKey])
                    .creationDate,
                    creationDate < sevenDaysAgo
                {
                    try FileManager.default.removeItem(at: file)
                    osLogger.info("Removed old log file: \(file.lastPathComponent)")
                }
            }
        } catch {
            osLogger.error("Failed to clean old log files: \(error.localizedDescription)")
        }
    }

    static func setMinimumLogLevel(_ level: LogLevel) {
        shared.minimumLogLevel = level
    }

    static func getMinimumLogLevel() -> LogLevel {
        shared.minimumLogLevel
    }

    static func getLogFileURL() -> URL? {
        shared.logFileURL
    }

    static func getAllLogFiles() -> [URL] {
        guard
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask,
            ).first
        else {
            return []
        }

        let logsDir = appSupport.appendingPathComponent("com.crown.clipboard/Logs")

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: logsDir, includingPropertiesForKeys: nil, options: [],
            )
            return files.filter { $0.pathExtension == "log" }.sorted {
                $0.lastPathComponent > $1.lastPathComponent
            }
        } catch {
            return []
        }
    }
}

let log = AppLogger.shared
