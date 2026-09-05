import AppKit
import SQLite

// MARK: - Row → Model 映射

extension PasteDataStore {
    func getItems(limit: Int = 50, offset: Int? = nil) async
        -> [PasteboardModel] {
        let rows = await sqlManager.search(
            filter: Col.hidden == 0,
            limit: limit,
            offset: offset
        )
        return mapRows(rows)
    }

    func mapRows(_ rows: [Row]) -> [PasteboardModel] {
        rows.compactMap { row in
            if let type = try? row.get(Col.type),
               let data = try? row.get(Col.data),
               let timestamp = try? row.get(Col.timestamp),
               let uniqueId = try? row.get(Col.uniqueId) {
                let id = try? row.get(Col.id)
                let appName = try? row.get(Col.appName)
                let appPath = try? row.get(Col.appPath)
                var showData = try? row.get(Col.showData)
                let searchText = try? row.get(Col.searchText)
                let length = try? row.get(Col.length)
                let group = try? row.get(Col.group)
                let tag = try? row.get(Col.tag)
                let hidden = ((try? row.get(Col.hidden)) ?? 0) != 0

                let pType = PasteboardType(type)

                if pType.isText(), showData == nil {
                    if let plain = NSAttributedString(
                        with: data,
                        type: pType
                    )?.string ?? String(data: data, encoding: .utf8) {
                        showData = String(plain.prefix(300)).data(
                            using: .utf8
                        )
                    }
                }

                let pasteModel = PasteboardModel(
                    pasteboardType: pType,
                    data: data,
                    showData: showData,
                    timestamp: timestamp,
                    appPath: appPath ?? "",
                    appName: appName ?? "",
                    searchText: searchText ?? "",
                    length: length ?? 0,
                    group: group ?? -1,
                    tag: tag ?? "",
                    hidden: hidden,
                    uniqueId: uniqueId
                )
                pasteModel.id = id
                repairTagIfNeeded(pasteModel)
                return pasteModel
            }
            return nil
        }
    }

    private func repairTagIfNeeded(_ model: PasteboardModel) {
        guard let storedType = PasteModelType(rawValue: model.tag),
              storedType == .link || storedType == .color,
              model.type != storedType,
              let id = model.id
        else {
            return
        }

        let correctedTag = model.type.tagValue
        guard !correctedTag.isEmpty,
              repairingTagIds.insert(id).inserted
        else {
            return
        }

        Task { [weak self] in
            guard let self else { return }

            let updated = await sqlManager.updateItemTag(
                id: id,
                expectedTag: storedType.tagValue,
                newTag: correctedTag
            )
            repairingTagIds.remove(id)

            if updated {
                PasteMetadataCache.shared.invalidateTagTypesCache()
            }
        }
    }
}
