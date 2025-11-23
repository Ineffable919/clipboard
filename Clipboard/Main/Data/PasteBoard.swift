//
//  PasteBoard.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import AppKit
import AVFoundation
import Foundation

final class PasteBoard {
    static let main = PasteBoard()

    private let pasteboard = NSPasteboard.general
    private let timerInterval = 1.0
    private var changeCount: Int
    private var pasteModel: PasteboardModel?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    init() {
        changeCount = pasteboard.changeCount
    }

    func startListening() {
        stopListening()

        timer = Timer.scheduledTimer(
            withTimeInterval: timerInterval,
            repeats: true,
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChangesInPasteboard()
            }
        }
    }

    func stopListening() {
        timer?.invalidate()
        timer = nil
    }

    private func checkForChangesInPasteboard() {
        guard pasteboard.changeCount != changeCount else {
            return
        }

        // 应用内复制，跳过记录（避免重复）
        if pasteModel != nil {
            changeCount = pasteboard.changeCount
            pasteModel = nil
            return
        }

        // 检查隐私设置：忽略机密内容
        if PasteUserDefaults.ignoreSensitiveContent {
            if containsSensitiveContent() {
                log.debug("检测到机密内容，跳过记录")
                changeCount = pasteboard.changeCount
                return
            }
        }

        // 检查隐私设置：忽略瞬时内容
        // if PasteUserDefaults.ignoreEphemeralContent {
        //     if isEphemeralContent() {
        //         log.debug("检测到瞬时内容，跳过记录")
        //         changeCount = pasteboard.changeCount
        //         return
        //     }
        // }

        // 检查隐私设置：忽略特定应用
        if let sourceApp = getSourceApplication() {
            let ignoredApps = PasteUserDefaults.ignoredApps
            let shouldIgnore = ignoredApps.contains { app in
                if let bundleId = app.bundleIdentifier,
                   bundleId == sourceApp.bundleIdentifier
                {
                    return true
                }
                return app.path == sourceApp.bundleURL?.path
            }

            if shouldIgnore {
                log.debug(
                    "来自忽略应用的内容，跳过记录: \(sourceApp.localizedName ?? "Unknown")",
                )
                changeCount = pasteboard.changeCount
                return
            }
        }

        guard let item = pasteboard.pasteboardItems?.first else { return }
        let types = item.types.map(\.rawValue)
        log.debug("可用类型 \(types)")

        PasteDataStore.main.addNewItem(pasteboard)
        changeCount = pasteboard.changeCount

        DispatchQueue.main.async {
            AppDelegate.shared?.triggerStatusBarPulse()
            if PasteUserDefaults.soundEnabled {
                self.playNotificationSound()
            }
        }
    }

    /// 检测是否包含敏感内容（密码、密钥等）
    private func containsSensitiveContent() -> Bool {
        let types = pasteboard.types ?? []

        // macOS 密码管理器通常使用特殊的 pasteboard type
        let sensitiveTypes = [
            "org.nspasteboard.ConcealedType",
            "com.apple.password",
            "com.apple.securetext",
        ]

        for type in types {
            if sensitiveTypes.contains(type.rawValue) {
                return true
            }
        }

        return false
    }

    /// 检测是否为瞬时内容
    private func isEphemeralContent() -> Bool {
        let types = pasteboard.types ?? []

        let ephemeralTypes = [
            "com.apple.pasteboard.promised-file-content-type",
            "dyn.",
        ]

        for type in types {
            for ephemeralType in ephemeralTypes {
                if type.rawValue.contains(ephemeralType) {
                    return true
                }
            }
        }

        return false
    }

    private func getSourceApplication() -> NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }

    private func playNotificationSound() {
        guard
            let url = Bundle.main.url(
                forResource: "copy",
                withExtension: "mp3",
            )
        else {
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            log.warn("播放音效失败: \(error.localizedDescription)")
        }
    }

    func pasteData(_ data: PasteboardModel, _ isAttribute: Bool = true) {
        data.updateDate()
        pasteModel = data
        if let itemId = data.id {
            PasteDataStore.main.updateDbItem(id: itemId, item: data)
        }
        PasteDataStore.main.moveItemToFirst(data)
        NSPasteboard.general.clearContents()

        let shouldPasteAsPlainText =
            !isAttribute || PasteUserDefaults.pasteOnlyText

        if (data.type == .string) || (data.type == .rich),
           shouldPasteAsPlainText
        {
            NSPasteboard.general.setString(data.searchText, forType: .string)
        } else if data.type == .file {
            if let filePaths = String(data: data.data, encoding: .utf8) {
                let paths = filePaths.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                var validURLs: [URL] = []

                for path in paths {
                    let fileURL = URL(fileURLWithPath: path)
                    if FileManager.default.fileExists(atPath: path) {
                        validURLs.append(fileURL)
                    }
                }

                guard !validURLs.isEmpty else {
                    return
                }

                pasteboard.writeObjects(validURLs as [NSPasteboardWriting])
            }
        } else {
            NSPasteboard.general.setData(
                data.data,
                forType: data.pasteboardType,
            )
        }
    }
}
