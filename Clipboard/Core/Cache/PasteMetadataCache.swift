//
//  PasteMetadataCache.swift
//  Clipboard
//
//  应用信息和标签类型的缓存管理
//

import Foundation

@MainActor
final class PasteMetadataCache {
    static let shared = PasteMetadataCache()

    private let sqlManager = PasteSQLManager.manager
    private var cachedAppInfo: [(name: String, path: String)]?
    private var cachedTagTypes: [PasteModelType]?

    private init() {}

    // MARK: - App Info

    func getAllAppInfo() async -> [(name: String, path: String)] {
        if let cached = cachedAppInfo {
            return cached
        }

        let appInfo = await sqlManager.getDistinctAppInfo()
        cachedAppInfo = appInfo
        return appInfo
    }

    func invalidateAppInfoCache(_ model: PasteboardModel) {
        guard !model.appName.isEmpty else { return }

        if cachedAppInfo == nil {
            Task {
                cachedAppInfo = await getAllAppInfo()
            }
            return
        }

        if let index = cachedAppInfo?.firstIndex(where: { $0.name == model.appName }) {
            cachedAppInfo?[index].path = model.appPath
        } else {
            cachedAppInfo?.insert(
                (name: model.appName, path: model.appPath),
                at: 0
            )
        }
    }

    // MARK: - Tag Types

    func getAllTagTypes() async -> [PasteModelType] {
        if let cached = cachedTagTypes {
            return cached
        }

        let tags = await sqlManager.getDistinctTags()
        let types = Self.buildTagTypes(from: tags)
        cachedTagTypes = types
        return types
    }

    func invalidateTagTypesCache(_ model: PasteboardModel? = nil) {
        guard let model, !model.tag.isEmpty else {
            cachedTagTypes = nil
            return
        }

        guard let modelType = Self.pasteModelType(from: model.tag) else {
            return
        }

        Task {
            if cachedTagTypes == nil {
                cachedTagTypes = await getAllTagTypes()
            }

            guard let cachedTagTypes, !cachedTagTypes.contains(modelType) else {
                return
            }

            var updatedTypes = cachedTagTypes
            updatedTypes.append(modelType)
            updatedTypes.sort(by: Self.typeOrder)
            self.cachedTagTypes = updatedTypes
        }
    }

    // MARK: - Cache Management

    func invalidateAllCaches() {
        cachedAppInfo = nil
        cachedTagTypes = nil
    }

    // MARK: - Private Helpers

    private static func pasteModelType(from tag: String) -> PasteModelType? {
        switch tag {
        case "image": .image
        case "string", "rich": .string
        case "file": .file
        case "link": .link
        case "color": .color
        default: nil
        }
    }

    private static func buildTagTypes(from tags: [String]) -> [PasteModelType] {
        let types = tags.compactMap { pasteModelType(from: $0) }

        var finalTypes: [PasteModelType] = []
        let hasString = types.contains(.string)
        let hasRich = types.contains(where: { $0 == .string })

        if hasString || hasRich {
            finalTypes.append(.string)
        }

        for type in types where type != .string {
            if !finalTypes.contains(type) {
                finalTypes.append(type)
            }
        }

        finalTypes.sort(by: typeOrder)
        return finalTypes
    }

    private static let order: [PasteModelType] = [
        .color, .file, .image, .link, .string,
    ]

    private static func typeOrder(
        _ type1: PasteModelType,
        _ type2: PasteModelType
    ) -> Bool {
        let index1 = order.firstIndex(of: type1) ?? order.count
        let index2 = order.firstIndex(of: type2) ?? order.count
        return index1 < index2
    }
}
