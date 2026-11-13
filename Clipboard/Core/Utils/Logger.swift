//
//  Logger.swift
//  clipboard
//
//  Created by crown on 2025/6/14
//

import Foundation
import os

nonisolated enum LogLevel: String, CaseIterable, Comparable, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

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

    #if DEBUG
        static let `default`: LogLevel = .debug
    #else
        static let `default`: LogLevel = .info
    #endif
}

/// Thread-safe logger. Public methods are nonisolated so callers need no `await`
///
/// - 消息为 `@autoclosure`，低于最低级别时不会拼接字符串
/// - Debug：打印到控制台
/// - Release：info 及以上写入按天切分的日志文件（保留 `LogFileSink.retentionDays` 天（15）），
///   error 同时写入系统日志；所有写入经单一消费者串行执行，保证顺序
final class AppLogger: Sendable {
    nonisolated static let shared = AppLogger()

    private let minimumLevel = OSAllocatedUnfairLock(
        initialState: LogLevel.default
    )

    #if !DEBUG
        private let osLogger = os.Logger(
            subsystem: "com.crown.clipboard",
            category: "AppLogger"
        )
        private let continuation: AsyncStream<LogEntry>.Continuation
    #endif

    private nonisolated init() {
        #if !DEBUG
            let (stream, continuation) = AsyncStream.makeStream(
                of: LogEntry.self
            )
            self.continuation = continuation
            Task.detached(priority: .utility) {
                let sink = LogFileSink()
                for await entry in stream {
                    sink?.write(entry)
                }
            }
        #endif
    }

    // MARK: - Public API (nonisolated — safe to call from any actor or thread)

    nonisolated func debug(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        emit(message, level: .debug, file: file, function: function, line: line)
    }

    nonisolated func info(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        emit(message, level: .info, file: file, function: function, line: line)
    }

    nonisolated func warn(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        emit(
            message,
            level: .warning,
            file: file,
            function: function,
            line: line
        )
    }

    nonisolated func error(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        emit(message, level: .error, file: file, function: function, line: line)
    }

    nonisolated func setMinimumLogLevel(_ level: LogLevel) {
        minimumLevel.withLock { $0 = level }
    }

    // MARK: - Private

    private nonisolated func emit(
        _ message: () -> String,
        level: LogLevel,
        file: String,
        function: String,
        line: Int
    ) {
        guard level >= minimumLevel.withLock({ $0 }) else { return }

        let text = message()
        let date = Date()
        let fileName = URL(fileURLWithPath: file).lastPathComponent

        #if DEBUG
            print(
                "\(date.formatted(LogFormat.timestamp)) [\(level.rawValue)] [\(fileName):\(line)] \(text)"
            )
        #else
            let body = "[\(fileName):\(line)] \(function) - \(text)"
            if level == .error {
                osLogger.error("\(body, privacy: .public)")
            }
            continuation.yield(
                LogEntry(date: date, level: level, message: body)
            )
        #endif
    }
}

// MARK: - Entry & formats

private nonisolated struct LogEntry: Sendable {
    let date: Date
    let level: LogLevel
    let message: String
}

private nonisolated enum LogFormat {
    /// 2026-11-13 15:49:33.414
    static let timestamp = Date.VerbatimFormatStyle(
        format: """
            \(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \
            \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)\
            .\(secondFraction: .fractional(3))
            """,
        timeZone: .current,
        calendar: Calendar(identifier: .gregorian)
    )

    /// 20261113
    static let fileDate = Date.VerbatimFormatStyle(
        format: "\(year: .defaultDigits)\(month: .twoDigits)\(day: .twoDigits)",
        timeZone: .current,
        calendar: Calendar(identifier: .gregorian)
    )
}

// MARK: - File sink

#if !DEBUG
    /// 按天写入日志文件；持有当天文件句柄，避免每条日志都开关文件
    ///
    /// 非 Sendable：只允许在创建它的那个消费任务里使用
    private nonisolated final class LogFileSink {
        /// 日志保留天数
        static let retentionDays = 15

        private let directory: URL
        private var handle: FileHandle?
        private var dayEnd = Date.distantPast

        init?() {
            guard
                let appSupport = FileManager.default.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                ).first
            else { return nil }
            directory = appSupport.appending(path: "com.crown.clipboard/logs")
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        deinit {
            try? handle?.close()
        }

        func write(_ entry: LogEntry) {
            guard let handle = handle(for: entry.date) else { return }
            let line =
                "[\(entry.date.formatted(LogFormat.timestamp))] [\(entry.level.rawValue)] \(entry.message)\n"
            try? handle.write(contentsOf: Data(line.utf8))
        }

        private func handle(for date: Date) -> FileHandle? {
            if let handle, date < dayEnd { return handle }

            // 跨天（或首次写入）：换文件并顺带清理过期日志
            try? handle?.close()
            handle = nil

            let calendar = Calendar(identifier: .gregorian)
            let start = calendar.startOfDay(for: date)
            dayEnd =
                calendar.date(byAdding: .day, value: 1, to: start)
                ?? date.addingTimeInterval(86400)

            let url = directory.appending(
                path: "clip-\(date.formatted(LogFormat.fileDate)).log"
            )
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            guard let opened = try? FileHandle(forWritingTo: url) else {
                return nil
            }
            _ = try? opened.seekToEnd()
            handle = opened

            pruneOldLogs(now: date)
            return opened
        }

        private func pruneOldLogs(now: Date) {
            let cutoff = now.addingTimeInterval(
                -Double(Self.retentionDays) * 86400
            )
            let files =
                (try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.contentModificationDateKey]
                )) ?? []
            for file in files
            where file.pathExtension == "log"
                && file.lastPathComponent.hasPrefix("clip-")
            {
                let modified = try? file.resourceValues(forKeys: [
                    .contentModificationDateKey
                ])
                .contentModificationDate
                if let modified, modified < cutoff {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }
#endif

nonisolated let log = AppLogger.shared
