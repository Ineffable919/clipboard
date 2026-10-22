//
//  PasteboardModel+RuntimeCache.swift
//  Clipboard
//
//  Non-persistent caches derived from immutable pasteboard payloads.
//

import AppKit

struct PasteboardModelRuntimeCache {
    var imageSize: CGSize?
    var backgroundColor: NSColor?
    var foregroundColor: NSColor?
    var richForegrounds: [NSColor] = []
    var previewForegrounds: [NSColor]?
    var filePaths: [String]?
    var ocrRegions: [OCRTextRegion]?
    var ocrKeyword: String?
    var hasBackgroundColor = false
    var needsBottomMask: Bool?
    var isMarkdown: Bool?
}

extension PasteboardModel {
    var cachedImageSize: CGSize? {
        get { runtimeCache.imageSize }
        set { runtimeCache.imageSize = newValue }
    }

    var cachedBackgroundColor: NSColor? {
        get { runtimeCache.backgroundColor }
        set { runtimeCache.backgroundColor = newValue }
    }

    var cachedForegroundColor: NSColor? {
        get { runtimeCache.foregroundColor }
        set { runtimeCache.foregroundColor = newValue }
    }

    var cachedRichForegrounds: [NSColor] {
        get { runtimeCache.richForegrounds }
        set { runtimeCache.richForegrounds = newValue }
    }

    var cachedPreviewForegrounds: [NSColor]? {
        get { runtimeCache.previewForegrounds }
        set { runtimeCache.previewForegrounds = newValue }
    }

    var cachedFilePaths: [String]? {
        get { runtimeCache.filePaths }
        set { runtimeCache.filePaths = newValue }
    }

    var cachedOCRRegions: [OCRTextRegion]? {
        get { runtimeCache.ocrRegions }
        set { runtimeCache.ocrRegions = newValue }
    }

    var cachedOCRKeyword: String? {
        get { runtimeCache.ocrKeyword }
        set { runtimeCache.ocrKeyword = newValue }
    }

    var cachedHasBackgroundColor: Bool {
        get { runtimeCache.hasBackgroundColor }
        set { runtimeCache.hasBackgroundColor = newValue }
    }

    var cachedNeedsBottomMask: Bool? {
        get { runtimeCache.needsBottomMask }
        set { runtimeCache.needsBottomMask = newValue }
    }

    var cachedIsMarkdown: Bool? {
        get { runtimeCache.isMarkdown }
        set { runtimeCache.isMarkdown = newValue }
    }
}
