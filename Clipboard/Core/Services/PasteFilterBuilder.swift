//
//  PasteFilterBuilder.swift
//  Clipboard
//
//  Created by crown on 2026/3/25.
//

import SQLite

enum PasteFilterBuilder {
    static func buildFilter(
        from criteria: SearchCriteria
    ) -> Expression<Bool>? {
        var clauses: [Expression<Bool>] = []

        // 关键词搜索
        if !criteria.keyword.isEmpty {
            clauses.append(Col.searchText.like("%\(criteria.keyword)%"))
        }

        // 分组筛选
        if let groupId = criteria.selectedGroupId {
            clauses.append(Col.group == groupId)
        } else {
            clauses.append(Col.hidden == 0)
        }

        // 类型筛选
        if !criteria.selectedTypes.isEmpty {
            var tagValues: [String] = []
            for type in criteria.selectedTypes {
                let value = type.tagValue
                if !value.isEmpty {
                    tagValues.append(value)
                }
            }
            if !tagValues.isEmpty {
                let tagCondition = tagValues.map { (Col.tag ?? "") == $0 }
                    .reduce(Expression<Bool>(value: false)) {
                        result,
                        condition in
                        result || condition
                    }
                clauses.append(tagCondition)
            }
        }

        // 应用筛选
        if !criteria.selectedAppNames.isEmpty {
            let appCondition = criteria.selectedAppNames.map {
                Col.appName == $0
            }
            .reduce(Expression<Bool>(value: false)) { $0 || $1 }
            clauses.append(appCondition)
        }

        // 日期筛选
        if let dateFilter = criteria.selectedDateFilter {
            let (start, end) = dateFilter.timestampRange()
            if let endTimestamp = end {
                let dateCondition = Col.ts >= start && Col.ts < endTimestamp
                clauses.append(dateCondition)
            } else {
                let dateCondition = Col.ts >= start
                clauses.append(dateCondition)
            }
        }

        return clauses.reduce(nil) { partial, next in
            if let existing = partial {
                return existing && next
            }
            return next
        }
    }
}
