//
//  AppColorService.swift
//  Clipboard
//
//  应用图标颜色管理：提取、缓存、查询
//

import AppKit
import Combine

@MainActor
final class AppColorService {
    static let shared = AppColorService()

    private static let fallbackHex = "#1765D9"

    private var colorDict: [String: String]
    private var checkedColors: Set<String> = []
    let changes = PassthroughSubject<String, Never>()
    private var fillingTask: Task<Void, Never>?

    private init() {
        var data = PasteUserDefaults.appColorData
        let stale = data.filter { $0.value == Self.fallbackHex }
        if !stale.isEmpty {
            for key in stale.keys {
                data.removeValue(forKey: key)
            }
            PasteUserDefaults.appColorData = data
        }
        colorDict = data
    }

    func updateColor(for model: PasteboardModel) {
        let name = model.appName
        guard needsUpdate(for: name) else { return }
        Task {
            let icon = await AppIconCache.shared.loadIcon(
                forAppID: model.appID,
                path: model.appPath
            )
            guard !Task.isCancelled else { return }
            storeColor(from: icon, name: name)
        }
    }

    /// 新旧备份都使用合并后的应用图标，已卸载应用无需再次访问原路径
    func fillMissingColors() {
        fillingTask?.cancel()
        let pending = SourceAppCache.shared.orderedApps.filter {
            needsUpdate(for: $0.name)
        }
        fillingTask = Task(priority: .utility) {
            for app in pending {
                guard !Task.isCancelled else { return }
                let icon = await AppIconCache.shared.loadIcon(
                    forAppID: app.id,
                    path: app.path
                )
                guard !Task.isCancelled else { return }
                storeColor(from: icon, name: app.name)
                await Task.yield()
            }
        }
    }

    func clearColors() {
        fillingTask?.cancel()
        fillingTask = nil
        colorDict.removeAll()
        checkedColors.removeAll()
        PasteUserDefaults.appColorData = [:]
    }

    private func needsUpdate(for name: String) -> Bool {
        guard !checkedColors.contains(name) else { return false }
        guard let hex = colorDict[name] else { return true }
        return NSColor(hex: hex).usingColorSpace(.sRGB).map {
            $0.saturationComponent < 0.4
        } ?? false
    }

    private func storeColor(from icon: NSImage, name: String) {
        guard needsUpdate(for: name),
            let hex = AppIconColorExtractor.extract(from: icon)
        else { return }
        checkedColors.insert(name)
        guard colorDict[name] != hex else { return }
        colorDict[name] = hex
        PasteUserDefaults.appColorData = colorDict
        changes.send(name)
    }

    func color(for model: PasteboardModel) -> NSColor {
        if let chip = model.getGroupChip() {
            return Self.paletteNSColor(at: chip.colorIndex)
        }
        if let colorStr = colorDict[model.appName] {
            return NSColor(hex: colorStr).withAlphaComponent(0.9)
        }
        return NSColor(hex: Self.fallbackHex)
    }

    private static func paletteNSColor(at index: Int) -> NSColor {
        CategoryChip.nsColor(at: index)
    }
}
