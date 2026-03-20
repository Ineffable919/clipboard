//
//  HorizontalScrollWheelBridge.swift
//  Clipboard
//
//  Created by Codex on 2026/3/19.
//

import AppKit
import SwiftUI

private enum HorizontalScrollWheelMapper {
    static func nextOffset(
        currentOffset: CGFloat,
        verticalDelta: CGFloat,
        usesPreciseDeltas: Bool,
        lineScrollDistance: CGFloat,
        maxOffset: CGFloat
    ) -> CGFloat {
        let horizontalDelta = usesPreciseDeltas
            ? verticalDelta
            : verticalDelta * max(lineScrollDistance, 1)

        return min(
            max(currentOffset - horizontalDelta, 0),
            maxOffset
        )
    }
}

private struct HorizontalScrollWheelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            HorizontalScrollWheelReader()
        }
    }
}

extension View {
    func horizontalMouseWheelScroll() -> some View {
        modifier(HorizontalScrollWheelModifier())
    }
}

private struct HorizontalScrollWheelReader: NSViewRepresentable {
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
                log.warn("未找到横向滚动容器，鼠标滚轮横向映射已跳过")
            } else if scrollView != nil {
                hasLoggedMissingScrollView = false
            }
        }

        private func startMonitoringIfNeeded() {
            guard monitorToken == nil else { return }

            monitorToken = NSEvent.addLocalMonitorForEvents(
                matching: .scrollWheel
            ) { [weak self] event in
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

            guard let scrollView,
                  event.window == view.window
            else {
                return event
            }

            let location = scrollView.convert(event.locationInWindow, from: nil)
            guard scrollView.bounds.contains(location),
                  shouldRemap(event, in: scrollView)
            else { return event }

            remapVerticalWheel(event, in: scrollView)
            return nil
        }

        private func shouldRemap(
            _ event: NSEvent,
            in scrollView: NSScrollView
        ) -> Bool {
            guard !event.modifierFlags.contains(.shift) else { return false }
            guard abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) else { return false }

            let visibleWidth = scrollView.contentView.documentVisibleRect.width
            let documentWidth = scrollView.documentView?.bounds.width ?? 0

            return documentWidth > visibleWidth
        }

        private func remapVerticalWheel(
            _ event: NSEvent,
            in scrollView: NSScrollView
        ) {
            let clipView = scrollView.contentView
            let visibleWidth = clipView.documentVisibleRect.width
            let documentWidth = scrollView.documentView?.bounds.width ?? 0
            let maxOffset = max(documentWidth - visibleWidth, 0)

            guard maxOffset > 0 else { return }

            let currentOffset = clipView.bounds.origin.x
            let nextOffset = HorizontalScrollWheelMapper.nextOffset(
                currentOffset: currentOffset,
                verticalDelta: event.scrollingDeltaY,
                usesPreciseDeltas: event.hasPreciseScrollingDeltas,
                lineScrollDistance: scrollView.horizontalLineScroll,
                maxOffset: maxOffset
            )

            guard nextOffset != currentOffset else { return }

            clipView.setBoundsOrigin(
                CGPoint(
                    x: nextOffset,
                    y: clipView.bounds.origin.y
                )
            )
            scrollView.reflectScrolledClipView(clipView)
        }

        private func locateScrollView(for view: NSView) -> NSScrollView? {
            if let enclosingScrollView = view.enclosingScrollView {
                return enclosingScrollView
            }

            let ancestorCandidates = view.ancestorChain.flatMap { ancestor in
                ancestor.descendantScrollViews()
            }

            if let bestCandidate = bestScrollViewMatch(
                from: ancestorCandidates,
                relativeTo: view
            ) {
                return bestCandidate
            }

            if let windowContentView = view.window?.contentView,
               let bestCandidate = bestScrollViewMatch(
                   from: windowContentView.descendantScrollViews(),
                   relativeTo: view
               )
            {
                return bestCandidate
            }
            return nil
        }

        private func bestScrollViewMatch(
            from candidates: [NSScrollView],
            relativeTo view: NSView
        ) -> NSScrollView? {
            let uniqueCandidates = Array(
                Dictionary(
                    candidates.map { (ObjectIdentifier($0), $0) },
                    uniquingKeysWith: { first, _ in first }
                ).values
            )

            let scoredCandidates = uniqueCandidates.compactMap {
                scrollView -> (NSScrollView, CGFloat, CGFloat)? in
                guard let scrollRect = scrollView.windowFrame,
                      let viewRect = view.windowFrame
                else {
                    return nil
                }

                let visibleWidth = scrollView.contentView.documentVisibleRect.width
                let documentWidth = scrollView.documentView?.bounds.width ?? 0
                guard documentWidth > visibleWidth else { return nil }

                let intersectionArea = scrollRect.intersection(viewRect).area
                let distance =
                    abs(scrollRect.midY - viewRect.midY)
                    + abs(scrollRect.midX - viewRect.midX)

                return (scrollView, intersectionArea, distance)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.2 < rhs.2
                }
                return lhs.1 > rhs.1
            }

            return scoredCandidates.first?.0
        }
    }
}

private final class HorizontalScrollWheelNSView: NSView {
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

private extension NSView {
    var ancestorChain: [NSView] {
        var chain: [NSView] = []
        var currentSuperview = superview

        while let superview = currentSuperview {
            chain.append(superview)
            currentSuperview = superview.superview
        }

        return chain
    }

    func descendantScrollViews() -> [NSScrollView] {
        var results: [NSScrollView] = []

        for subview in subviews {
            if let scrollView = subview as? NSScrollView {
                results.append(scrollView)
            }
            results.append(contentsOf: subview.descendantScrollViews())
        }

        return results
    }

    var windowFrame: CGRect? {
        guard window != nil else { return nil }
        return convert(bounds, to: nil)
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}
