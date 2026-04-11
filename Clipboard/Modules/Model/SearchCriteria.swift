//
//  SearchCriteria.swift
//  Clipboard
//
//  Created by crown
//

import Foundation

// MARK: - DateFilterOption

enum DateFilterOption: String, CaseIterable, Equatable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This week"
    case lastWeek = "Last week"
    case thisMonth = "This month"

    var displayName: String {
        switch self {
        case .today: String(localized: .today)
        case .yesterday: String(localized: .yesterday)
        case .thisWeek: String(localized: .thisWeek)
        case .lastWeek: String(localized: .lastWeek)
        case .thisMonth: String(localized: .thisMonth)
        }
    }

    func timestampRange() -> (start: Int64, end: Int64?) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return (Int64(startOfDay.timeIntervalSince1970), nil)

        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            let startOfYesterday = calendar.startOfDay(for: yesterday)
            let endOfYesterday = calendar.date(byAdding: .day, value: 1, to: startOfYesterday) ?? now
            return (Int64(startOfYesterday.timeIntervalSince1970), Int64(endOfYesterday.timeIntervalSince1970))

        case .thisWeek:
            let startOfWeek = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            ) ?? now
            return (Int64(startOfWeek.timeIntervalSince1970), nil)

        case .lastWeek:
            let thisWeekStart = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            ) ?? now
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? now
            return (Int64(lastWeekStart.timeIntervalSince1970), Int64(thisWeekStart.timeIntervalSince1970))

        case .thisMonth:
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            ) ?? now
            return (Int64(startOfMonth.timeIntervalSince1970), nil)
        }
    }
}

// MARK: - SearchCriteria

/// 搜索条件：关键词 + 顶栏分组（自定义 chip）+ 原始筛选条件
struct SearchCriteria: Equatable {
    var keyword: String
    var chipGroup: Int
    var selectedTypes: Set<PasteModelType>
    var selectedAppNames: Set<String>
    var selectedDateFilter: DateFilterOption?

    static let empty = SearchCriteria(
        keyword: "",
        chipGroup: -1,
        selectedTypes: [],
        selectedAppNames: [],
        selectedDateFilter: nil
    )

    var isEmpty: Bool {
        keyword.isEmpty
            && chipGroup == -1
            && selectedTypes.isEmpty
            && selectedAppNames.isEmpty
            && selectedDateFilter == nil
    }
}
