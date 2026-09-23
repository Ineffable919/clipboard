//
//  FilterAppInfo.swift
//  Clipboard
//
//  Application metadata displayed by the filter popover.
//

import AppKit

struct FilterAppInfo {
    let id: Int64
    let name: String
    let path: String
    var icon: NSImage?
}
