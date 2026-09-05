import Foundation
import SQLite

/// 显示顺序独立于时间戳；只读取 ID 和序号，不加载剪贴板内容。
enum PasteOrder {
    nonisolated static func setup(on database: Connection) throws {
        try database.transaction(.immediate) {
            let columns = try database.prepare("PRAGMA table_info(Clip)")
                .compactMap { $0[1] as? String }
            if !columns.contains("sort_order") {
                try database.run("ALTER TABLE Clip ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0")
                try database.run("""
                    WITH ranks AS (
                        SELECT id, ROW_NUMBER() OVER (ORDER BY timestamp, id) AS rank
                        FROM Clip
                    )
                    UPDATE Clip SET sort_order = (SELECT rank FROM ranks WHERE ranks.id = Clip.id)
                    """)
            }
            try database.run("CREATE INDEX IF NOT EXISTS idx_sort_order ON Clip(sort_order DESC, id DESC)")
            try database.run("CREATE INDEX IF NOT EXISTS idx_hidden_order ON Clip(hidden, sort_order DESC, id DESC)")
            try database.run("CREATE INDEX IF NOT EXISTS idx_group_order ON Clip(\"group\", sort_order DESC, id DESC)")
        }
    }

    nonisolated static func orderedIDs(on database: Connection) throws -> [Int64] {
        try database.prepare(Table("Clip").select(Col.id).order(Col.sortOrder.desc, Col.id.desc))
            .map { $0[Col.id] }
    }

    /// before 优先；结果末尾使用 after，避免误移到尚未加载的历史记录之后。
    nonisolated static func move(
        _ ids: [Int64],
        before: Int64?,
        after: Int64?,
        on database: Connection
    ) throws -> [Int64] {
        var result: [Int64] = []
        try database.transaction(.immediate) {
            let table = Table("Clip")
            let rows = try Array(database.prepare(
                table.select(Col.id, Col.sortOrder).order(Col.sortOrder.desc, Col.id.desc)
            ))
            let previous = rows.map { $0[Col.id] }
            let moved = Set(ids)
            guard !ids.isEmpty, moved.count == ids.count,
                  moved.isSubset(of: Set(previous)) else { throw PasteOrderError.missingItem }
            var reordered = previous.filter { !moved.contains($0) }
            let destination: Int
            if let before, let index = reordered.firstIndex(of: before) {
                destination = index
            } else if before == nil, let after, let index = reordered.firstIndex(of: after) {
                destination = index + 1
            } else {
                throw PasteOrderError.missingItem
            }
            reordered.insert(contentsOf: ids, at: destination)

            // 将原有序号分配给新顺序；区间外的记录不产生 UPDATE。
            for index in reordered.indices where reordered[index] != previous[index] {
                try database.run(table.filter(Col.id == reordered[index]).update(
                    Col.sortOrder <- rows[index][Col.sortOrder]
                ))
            }
            result = reordered
        }
        return result
    }
}
