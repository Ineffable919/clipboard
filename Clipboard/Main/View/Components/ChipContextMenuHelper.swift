//
//  ChipContextMenuHelper.swift
//  Clipboard
//
//  Created by crown on 2026/1/29.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared Drop Types

enum ChipDropTypes {
    static let types: [UTType] = [
        .text,
        .rtf,
        .rtfd,
        .fileURL,
        .png,
        .tiff,
        .data,
    ]
}

// MARK: - AppKit Context Menu Helper

struct ChipContextMenuHelper: NSViewRepresentable {
    let chip: CategoryChip
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onColorChange: (Int) -> Void
    let onHoverChanged: (Bool) -> Void

    func makeNSView(context _: Context) -> ChipContextMenuView {
        let view = ChipContextMenuView()
        view.chip = chip
        view.onEdit = onEdit
        view.onDelete = onDelete
        view.onColorChange = onColorChange
        view.onHoverChanged = onHoverChanged
        return view
    }

    func updateNSView(_ nsView: ChipContextMenuView, context _: Context) {
        nsView.chip = chip
        nsView.onEdit = onEdit
        nsView.onDelete = onDelete
        nsView.onColorChange = onColorChange
        nsView.onHoverChanged = onHoverChanged
    }
}

final class ChipContextMenuView: NSView {
    var chip: CategoryChip?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onColorChange: ((Int) -> Void)?
    var onHoverChanged: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        if let trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with _: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with _: NSEvent) {
        onHoverChanged?(false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let currentEvent = NSApp.currentEvent,
              currentEvent.type == .rightMouseDown
        else {
            return nil
        }
        return super.hitTest(point)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let chip, !chip.isSystem else {
            super.rightMouseDown(with: event)
            return
        }

        let menu = NSMenu()

        let editItem = NSMenuItem(title: "编辑", action: #selector(editAction), keyEquivalent: "")
        editItem.target = self
        editItem.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
        menu.addItem(editItem)

        let deleteItem = NSMenuItem(title: "删除", action: #selector(deleteAction), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        menu.addItem(deleteItem)

        menu.addItem(.separator())

        let colorItem = NSMenuItem()
        colorItem.title = ""
        let colorView = ColorPaletteView(
            currentColorIndex: chip.colorIndex,
            onColorChange: { [weak self] index in
                menu.cancelTracking()
                self?.onColorChange?(index)
            }
        )
        colorItem.view = colorView
        menu.addItem(colorItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func editAction() {
        onEdit?()
    }

    @objc private func deleteAction() {
        onDelete?()
    }
}

// MARK: - Color Palette View

final class ColorPaletteView: NSView {
    private let currentColorIndex: Int
    private let onColorChange: (Int) -> Void

    init(currentColorIndex: Int, onColorChange: @escaping (Int) -> Void) {
        self.currentColorIndex = currentColorIndex
        self.onColorChange = onColorChange
        super.init(frame: .zero)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        let circleSize: CGFloat = 14
        let spacing: CGFloat = 12
        let padding: CGFloat = 16
        let colors = CategoryChip.palette

        let totalWidth = CGFloat(colors.count) * circleSize + CGFloat(colors.count - 1) * spacing + padding * 2
        let totalHeight = circleSize + padding * 2

        frame = NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight)

        for (index, color) in colors.enumerated() {
            let circleView = ColorCircleView(
                color: NSColor(color),
                isSelected: index == currentColorIndex,
                onTap: { [weak self] in
                    self?.onColorChange(index)
                }
            )
            circleView.frame = NSRect(
                x: padding + CGFloat(index) * (circleSize + spacing),
                y: padding,
                width: circleSize,
                height: circleSize
            )
            addSubview(circleView)
        }
    }
}

// MARK: - Color Circle View

final class ColorCircleView: NSView {
    private let color: NSColor
    private let isSelected: Bool
    private let onTap: () -> Void
    private var isHovered = false

    private var trackingArea: NSTrackingArea?

    init(color: NSColor, isSelected: Bool, onTap: @escaping () -> Void) {
        self.color = color
        self.isSelected = isSelected
        self.onTap = onTap
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        if let trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with _: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with _: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onTap()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(ovalIn: rect)

        color.setFill()
        path.fill()

        if isSelected || isHovered {
            NSColor.white.withAlphaComponent(0.8).setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }
}
