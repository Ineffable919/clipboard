//
//  HorizontalScrollWheelBridge.swift
//  Clipboard
//
//  Created by Codex on 2026/3/19.
//

import AppKit
import SwiftUI

// MARK: - Offset Calculator

private enum HorizontalScrollWheelMapper {
    static func nextOffset(
        currentOffset: CGFloat,
        verticalDelta: CGFloat,
        usesPreciseDeltas: Bool,
        lineScrollDistance: CGFloat,
        minOffset: CGFloat,
        maxOffset: CGFloat
    ) -> CGFloat {
        let horizontalDelta = usesPreciseDeltas
            ? verticalDelta
            : verticalDelta * max(lineScrollDistance, 1)

        return min(
            max(currentOffset - horizontalDelta, minOffset),
            maxOffset
        )
    }
}

// MARK: - NSViewRepresentable

struct HorizontalScrollWheelReader: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> HorizontalScrollWheelNSView {
        let view = HorizontalScrollWheelNSView()
        view.coordinator = context.coordinator
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(
        _ nsView: HorizontalScrollWheelNSView,
        context: Context
    ) {
        nsView.coordinator = context.coordinator
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(
        _ nsView: HorizontalScrollWheelNSView,
        coordinator: Coordinator
    ) {
        coordinator.detach(from: nsView)
    }
}

// MARK: - Coordinator

extension HorizontalScrollWheelReader {
    @MainActor
    final class Coordinator {
        private weak var view: HorizontalScrollWheelNSView?
        private weak var scrollView: NSScrollView?
        private var monitorToken: Any?
        private var hasLoggedMissingScrollView = false

        func attach(to view: HorizontalScrollWheelNSView) {
            self.view = view
            invalidateScrollViewCache()
            resolveScrollViewIfNeeded(force: true)
            startMonitoringIfNeeded()
        }

        func detach(from view: HorizontalScrollWheelNSView) {
            guard self.view === view else { return }
            stopMonitoring()
            self.view = nil
            invalidateScrollViewCache()
        }

        func invalidateScrollViewCache() {
            scrollView = nil
            hasLoggedMissingScrollView = false
        }

        func resolveScrollViewIfNeeded(force: Bool = false) {
            guard let view else { return }

            if !force,
               let scrollView,
               scrollView.window == view.window,
               scrollView.documentView != nil
            {
                return
            }

            scrollView = locateScrollView(for: view)
            if scrollView == nil, !hasLoggedMissingScrollView {
                hasLoggedMissingScrollView = true
                log.debug("未找到横向滚动容器，鼠标滚轮横向映射已跳过")
            } else if scrollView != nil {
                hasLoggedMissingScrollView = false
            }
        }

        private func startMonitoringIfNeeded() {
            guard monitorToken == nil else { return }
            monitorToken = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        private func stopMonitoring() {
            guard let monitorToken else { return }
            NSEvent.removeMonitor(monitorToken)
            self.monitorToken = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let view else { return event }
            resolveScrollViewIfNeeded()

            guard let scrollView, event.window == view.window else { return event }

            let location = scrollView.convert(event.locationInWindow, from: nil)
            guard scrollView.bounds.contains(location),
                  shouldRemap(event, in: scrollView)
            else { return event }

            remapVerticalWheel(event, in: scrollView)
            return nil
        }

        private func shouldRemap(_ event: NSEvent, in scrollView: NSScrollView) -> Bool {
            guard !event.modifierFlags.contains(.shift) else { return false }
            guard abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) else { return false }

            let visibleWidth = scrollView.contentView.documentVisibleRect.width
            let documentWidth = scrollView.documentView?.bounds.width ?? 0
            let insets = scrollView.contentInsets
            return documentWidth + insets.left + insets.right > visibleWidth
        }

        private func remapVerticalWheel(_ event: NSEvent, in scrollView: NSScrollView) {
            let clipView = scrollView.contentView
            let visibleWidth = clipView.documentVisibleRect.width
            let documentWidth = scrollView.documentView?.bounds.width ?? 0
            let insets = scrollView.contentInsets
            let minOffset = -insets.left
            let maxOffset = max(documentWidth + insets.right - visibleWidth, minOffset)

            guard maxOffset > minOffset else { return }

            let currentOffset = clipView.bounds.origin.x
            let nextOffset = HorizontalScrollWheelMapper.nextOffset(
                currentOffset: currentOffset,
                verticalDelta: event.scrollingDeltaY,
                usesPreciseDeltas: event.hasPreciseScrollingDeltas,
                lineScrollDistance: scrollView.horizontalLineScroll,
                minOffset: minOffset,
                maxOffset: maxOffset
            )

            guard nextOffset != currentOffset else { return }

            clipView.setBoundsOrigin(CGPoint(x: nextOffset, y: clipView.bounds.origin.y))
            scrollView.reflectScrolledClipView(clipView)
        }

        private func locateScrollView(for view: NSView) -> NSScrollView? {
            if let enclosingScrollView = view.enclosingScrollView {
                return enclosingScrollView
            }

            let ancestorCandidates = view.ancestorChain.flatMap { $0.descendantScrollViews() }
            if let best = bestScrollViewMatch(from: ancestorCandidates, relativeTo: view) {
                return best
            }

            if let windowContentView = view.window?.contentView,
               let best = bestScrollViewMatch(
                   from: windowContentView.descendantScrollViews(),
                   relativeTo: view
               )
            {
                return best
            }
            return nil
        }

        private func bestScrollViewMatch(
            from candidates: [NSScrollView],
            relativeTo view: NSView
        ) -> NSScrollView? {
            let unique = Array(
                Dictionary(
                    candidates.map { (ObjectIdentifier($0), $0) },
                    uniquingKeysWith: { first, _ in first }
                ).values
            )

            return unique
                .compactMap { scrollView -> (NSScrollView, CGFloat, CGFloat)? in
                    guard let scrollRect = scrollView.windowFrame,
                          let viewRect = view.windowFrame
                    else { return nil }

                    let visibleWidth = scrollView.contentView.documentVisibleRect.width
                    let documentWidth = scrollView.documentView?.bounds.width ?? 0
                    let insets = scrollView.contentInsets
                    guard documentWidth + insets.left + insets.right > visibleWidth else { return nil }

                    let intersectionArea = scrollRect.intersection(viewRect).area
                    let distance = abs(scrollRect.midY - viewRect.midY) + abs(scrollRect.midX - viewRect.midX)
                    return (scrollView, intersectionArea, distance)
                }
                .sorted { lhs, rhs in
                    lhs.1 == rhs.1 ? lhs.2 < rhs.2 : lhs.1 > rhs.1
                }
                .first?.0
        }
    }
}

// MARK: - NSView Subclass

final class HorizontalScrollWheelNSView: NSView {
    weak var coordinator: HorizontalScrollWheelReader.Coordinator?

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        coordinator?.invalidateScrollViewCache()
        coordinator?.resolveScrollViewIfNeeded(force: true)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.invalidateScrollViewCache()
        coordinator?.resolveScrollViewIfNeeded(force: true)
    }
}
