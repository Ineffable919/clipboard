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
        if let index = cachedAppInfo?.firstIndex(where: {
            $0.name == model.appName
        }) {
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
        let types = tags.compactMap { tag -> PasteModelType? in
            switch tag {
            case "image": .image
            case "string": .string
            case "rich": .rich
            case "file": .file
            case "link": .link
            case "color": .color
            default: nil
            }
        }

        var finalTypes: [PasteModelType] = []
        let hasString = types.contains(.string)
        let hasRich = types.contains(.rich)

        if hasString || hasRich {
            finalTypes.append(.string)
        }

        for type in types where type != .string && type != .rich {
            if !finalTypes.contains(type) {
                finalTypes.append(type)
            }
        }

        finalTypes.sort(by: Self.typeOrder)
        cachedTagTypes = finalTypes
        return finalTypes
    }

    func invalidateTagTypesCache(_ model: PasteboardModel? = nil) {
        guard let model, !model.tag.isEmpty else {
            cachedTagTypes = nil
            return
        }

        let modelType: PasteModelType? =
            switch model.tag {
            case "image": .image
            case "string", "rich": .string
            case "file": .file
            case "link": .link
            case "color": .color
            default: nil
            }

        guard let modelType else { return }

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

    // MARK: - Private

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
