//
//  PasteboardModel+ItemProvider.swift
//  Clipboard
//
//  Created by crown on 2026/3/11.
//

import AppKit

extension PasteboardModel {
    func itemProvider() -> NSItemProvider {
        if type == .string || type == .color || type == .link {
            let provider = NSItemProvider()
            let dataCopy = data
            let typeIdentifier = pasteboardType.rawValue
            provider.registerDataRepresentation(
                forTypeIdentifier: typeIdentifier,
                visibility: .all
            ) { completion in
                completion(dataCopy, nil)
                return nil
            }
            return provider
        }

        if type == .rich {
            if #available(macOS 15.0, *) {
                let provider = NSItemProvider()
                let dataCopy = data
                let typeIdentifier = pasteboardType.rawValue
                provider.registerDataRepresentation(
                    forTypeIdentifier: typeIdentifier,
                    visibility: .all
                ) { completion in
                    completion(dataCopy, nil)
                    return nil
                }
                return provider
            } else {
                let provider = NSItemProvider(
                    object: attributeString.string as NSString
                )
                let dataCopy = data
                let typeIdentifier = pasteboardType.rawValue
                provider.registerDataRepresentation(
                    forTypeIdentifier: typeIdentifier,
                    visibility: .all
                ) { completion in
                    completion(dataCopy, nil)
                    return nil
                }
                return provider
            }
        }

        if type == .image {
            let name = appName + "-" + timestamp.date()
            if #available(macOS 15.0, *) {
                let provider = NSItemProvider()
                provider.registerDataRepresentation(
                    forTypeIdentifier: pasteboardType.rawValue,
                    visibility: .all
                ) { [self] completion in
                    completion(data, nil)
                    return nil
                }
                provider.suggestedName = name
                return provider
            } else {
                if let image = NSImage(data: data) {
                    let provider = NSItemProvider(object: image)
                    provider.suggestedName = name
                    return provider
                }
            }
        }

        if type == .file {
            if let paths = cachedFilePaths, !paths.isEmpty {
                let path = paths[0]
                guard path.hasPrefix("/") else {
                    return NSItemProvider()
                }

                let fileURL = URL(fileURLWithPath: path)
                guard fileURL.isFileURL else {
                    return NSItemProvider()
                }

                let hasAccess = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }

                if let provider = NSItemProvider(contentsOf: fileURL) {
                    provider.suggestedName =
                        fileURL.deletingPathExtension().lastPathComponent
                    return provider
                }

                return NSItemProvider()
            }
        }

        return NSItemProvider()
    }

    static func generateUniqueId(
        for type: PasteboardType,
        data: Data
    ) -> String {
        switch type {
        case .png, .tiff:
            let prefix = data.prefix(1024)
            return "\(prefix.sha256Hex)-\(data.count)"
        case .rtf, .rtfd:
            if let attributeString = NSAttributedString(with: data, type: type),
               let textData = attributeString.string.data(using: .utf8)
            {
                return textData.sha256Hex
            }
            return data.sha256Hex
        default:
            return data.sha256Hex
        }
    }
}
