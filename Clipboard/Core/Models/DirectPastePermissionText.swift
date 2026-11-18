//
//  DirectPastePermissionText.swift
//  Clipboard
//
//  Created by crown on 2026/11/18
//

import Foundation

struct DirectPastePermissionText {
    let button: LocalizedStringResource
    let title: LocalizedStringResource
    let alertTitle: LocalizedStringResource
    let alertMessage: LocalizedStringResource

    static var current: Self {
        if #available(macOS 27.3, *) {
            return Self(
                button: .permissionOpenSettings,
                title: .directPastePermissionTitle,
                alertTitle: .directPastePermissionRequired,
                alertMessage: .directPastePermissionMessage
            )
        }

        if #available(macOS 27.0, *) {
            return Self(
                button: .generalAllowDeviceControlAndDataAccess,
                title: .deviceControlAndDataAccessTitle,
                alertTitle: .deviceControlAndDataAccessRequired,
                alertMessage: .deviceControlAndDataAccessMessage
            )
        }

        return Self(
            button: .generalEnableAccess,
            title: .privacyAccessPermissionTitle,
            alertTitle: .accessTitle,
            alertMessage: .accessMessage
        )
    }
}
