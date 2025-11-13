//
//  Date+Extension.swift
//  Clipboard
//
//  Created by crown on 2025/9/23.
//

import AppKit

extension Int64 {
    var timeAgo: String {
        timeAgo(relativeTo: Date())
    }

    func timeAgo(relativeTo currentDate: Date) -> String {
        let diffDate = NSCalendar.current.dateComponents(
            [.month, .day, .hour, .minute],
            from: Date(timeIntervalSince1970: TimeInterval(self)),
            to: currentDate
        )
        let seconds = currentDate.timeIntervalSince(
            Date(timeIntervalSince1970: TimeInterval(self))
        )
        if seconds >= 30 && seconds < 60 {
            return "30秒前"
        }
        if let month = diffDate.month, month > 0 {
            return "\(month)月前"
        } else if let day = diffDate.day, day > 0 {
            return "\(day)天前"
        } else if let hour = diffDate.hour, hour > 0 {
            return "\(hour)小时前"
        } else if let minute = diffDate.minute, minute > 0 {
            return "\(minute)分钟前"
        } else {
            return "现在"
        }
    }
}
