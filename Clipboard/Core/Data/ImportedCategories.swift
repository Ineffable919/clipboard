import Foundation

/// 分类映射只计算一次，记录导入时按旧 ID 直接查找。
nonisolated struct ImportedCategories {
    let groupIDs: [Int: Int]
    let chips: [CategoryChip]

    @MainActor init(data: Data?, existingChips: [CategoryChip], reservedIDs: Set<Int>) {
        let existingIDs = Set(existingChips.map(\.id)).union(reservedIDs)
        let imported = data.flatMap { try? JSONDecoder().decode([CategoryChip].self, from: $0) } ?? []
        let userChips = imported.filter { !$0.isSystem && $0.id >= 0 }
        var maximumID = max(existingIDs.max() ?? -1, userChips.map(\.id).max() ?? -1)
        var mapping: [Int: Int] = [:]
        var mappedChips: [CategoryChip] = []
        for chip in userChips where mapping[chip.id] == nil {
            if let existing = existingChips.first(where: {
                !$0.isSystem && $0.name == chip.name && $0.colorIndex == chip.colorIndex
            }) {
                mapping[chip.id] = existing.id
                continue
            }
            let newID: Int
            if existingIDs.contains(chip.id) {
                maximumID += 1
                newID = maximumID
            } else {
                newID = chip.id
            }
            mapping[chip.id] = newID
            mappedChips.append(CategoryChip(
                id: newID, name: chip.name, colorIndex: chip.colorIndex, isSystem: false
            ))
        }
        groupIDs = mapping
        chips = mappedChips
    }
}
