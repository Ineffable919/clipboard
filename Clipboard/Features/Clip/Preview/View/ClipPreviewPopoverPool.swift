//
//  ClipPreviewPopoverPool.swift
//  Clipboard
//
//  预览 Popover 复用池：关闭动画结束后回收，避免每次打开都重建窗口与视图树
//

import AppKit

@MainActor
final class ClipPreviewPopoverPool {
    private var popovers: [ClipPreviewPopover] = []
    private var idle: [ClipPreviewPopover] = []

    func dequeue() -> ClipPreviewPopover {
        if let popover = idle.popLast() {
            return popover
        }
        let popover = ClipPreviewPopover()
        popover.onDidClose = { [weak self, weak popover] in
            guard let self, let popover else { return }
            idle.append(popover)
        }
        popovers.append(popover)
        return popover
    }
}
