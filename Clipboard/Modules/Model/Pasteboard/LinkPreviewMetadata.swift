//
//  LinkPreviewMetadata.swift
//  Clipboard
//
//  Cached result of an LPMetadataProvider fetch for a link card.
//

import AppKit

/// Stores the fetched metadata for a link so we don't re-fetch on every cell reuse.
struct LinkPreviewMetadata {
    let title: String?
    let previewImage: NSImage?
    let iconImage: NSImage?
}
