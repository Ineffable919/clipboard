//
//  UserInterfaceItemIdentifier.swift
//  Clipboard
//
//  Created by crown on 2026/4/11.
//

import Cocoa

protocol UserInterfaceItemIdentifier {
    static var identifier: NSUserInterfaceItemIdentifier { get }
    static var nib: NSNib? { get }
}

extension UserInterfaceItemIdentifier {
    static var identifier: NSUserInterfaceItemIdentifier {
        .init(rawValue: String(describing: Self.self))
    }

    static var nib: NSNib? {
        FileManager.default.fileExists(
            atPath: Bundle.main.path(
                forResource: String(describing: Self.self),
                ofType: "nib"
            ) ?? ""
        )
            ? NSNib(
                nibNamed: String(describing: Self.self),
                bundle: Bundle.main
            ) : nil
    }
}
