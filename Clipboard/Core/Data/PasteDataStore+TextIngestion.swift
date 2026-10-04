import AppKit

extension PasteDataStore {
    func ingestText(
        _ data: Data,
        sourceApp: NSRunningApplication?,
        chipId: Int,
        after previous: Task<Void, Never>?
    ) -> Task<Void, Never> {
        let app = sourceApp ?? NSWorkspace.shared.frontmostApplication
        let appPath = app?.bundleURL?.path ?? ""
        let appName = app?.localizedName ?? ""
        let bundleID = app?.bundleIdentifier
        let timestamp = Int64(Date().timeIntervalSince1970)
        let tag = PasteboardModel.calculateTag(type: .string, content: data)
        return Task {
            await previous?.value
            guard let content = await Task.detached(priority: .utility, operation: {
                PasteboardTextPreparation.prepare(data)
            }).value else { return }
            let model = PasteboardModel(
                pasteboardType: .string,
                data: data,
                showData: content.showData,
                timestamp: timestamp,
                appPath: appPath,
                appName: appName,
                searchText: content.searchText,
                length: content.length,
                group: chipId,
                tag: tag,
                uniqueId: content.uniqueId,
                sourceBundleID: bundleID
            )
            PasteMetadataCache.shared.invalidateTagTypesCache(model)
            await insertModel(model)
        }
    }
}
