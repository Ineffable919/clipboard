//
//  ClipListPresenter.swift
//  Clipboard
//
//  统一管理 dataList 订阅、DataChangeType 分发、追加加载和滚动触底检测。
//  使用方通过闭包注入快照更新、选中管理等视图操作。
//

import AppKit
import Combine

@MainActor
final class ClipListPresenter {
    private let dataStore = PasteDataStore.main
    private var cancellables = Set<AnyCancellable>()
    private var wasEmpty = true

    // MARK: - Snapshot

    /// 全量刷新：接收新数据、是否动画、完成回调。
    var applyFull: (_ items: [PasteboardModel], _ animating: Bool, _ completion: (() -> Void)?) -> Void = { _, _, _ in }
    var applyReorder: (_ items: [PasteboardModel]) -> Void = { _ in }
    /// 追加新条目到现有快照。
    var appendItems: (_ newItems: [PasteboardModel]) -> Void = { _ in }
    /// 返回当前快照中的所有条目，用于去重。
    var currentSnapshotItems: () -> [PasteboardModel] = { [] }

    // MARK: - Selection

    var resetSelection: () -> Void = {}
    var restoreSelection: () -> Void = {}
    var adjustAfterDelete: () -> Void = {}

    // MARK: - Reconfigure

    /// 强制刷新指定条目的 cell 内容（属性变更但 identity 未变时使用，如 group 变更）。
    var reconfigureItems: (_ items: [PasteboardModel]) -> Void = { _ in }

    // MARK: - Empty State

    var updateEmptyState: (_ isEmpty: Bool) -> Void = { _ in }

    // MARK: - Preview

    var previewIsShown: () -> Bool = { false }
    var closePreview: () -> Void = {}
    var reopenPreview: () -> Void = {}

    // MARK: - Load More

    var isVerticalScroll: Bool = false
    var loadMoreThreshold: CGFloat = 0

    // MARK: - Start

    func startObserving(scrollView: NSScrollView) {
        dataStore.dataList
            .map { [weak self] items in (items, self?.dataStore.lastDataChangeType ?? .reset) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items, change in
                self?.handleDataChange(change, items: items)
            }
            .store(in: &cancellables)

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.publisher(
            for: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
        .sink { [weak self] _ in self?.checkLoadMore(scrollView: scrollView) }
        .store(in: &cancellables)
    }

    // MARK: - Private

    private func handleDataChange(_ changeType: PasteDataStore.DataChangeType, items: [PasteboardModel]) {
        let prevWasEmpty = wasEmpty
        wasEmpty = items.isEmpty

        let wasShowingPreview = previewIsShown()
        let shouldDismissPreview = ![PasteDataStore.DataChangeType.loadMore, .update, .reorder].contains(changeType)
        if shouldDismissPreview, wasShowingPreview {
            closePreview()
        }

        switch changeType {
        case .reorder:
            applyReorder(items)
        case .new, .searchFilter, .moveToFirst, .reset:
            applyFull(items, false) { [weak self] in
                guard let self else { return }
                resetSelection()
                // .new 时 preview 关闭后重新定位到新选中项（与 .update 行为一致）
                if wasShowingPreview, changeType == .new {
                    reopenPreview()
                }
            }
        case .delete:
            applyFull(items, true) { [weak self] in self?.adjustAfterDelete() }
        case .loadMore:
            appendNewItems(items)
        case .update:
            reconfigureItems(items)
            restoreSelection()
            if wasShowingPreview {
                reopenPreview()
            }
        }

        updateEmptyState(items.isEmpty)

        let isAppendOrUpdate = [PasteDataStore.DataChangeType.loadMore, .update].contains(changeType)
        if prevWasEmpty, !items.isEmpty, isAppendOrUpdate {
            resetSelection()
        }
    }

    private func appendNewItems(_ items: [PasteboardModel]) {
        let existingIds = Set(currentSnapshotItems().map(\.uniqueId))
        let newItems = items.filter { !existingIds.contains($0.uniqueId) }
        if !newItems.isEmpty {
            appendItems(newItems)
        }
    }

    private func checkLoadMore(scrollView: NSScrollView) {
        guard dataStore.hasMoreData, !dataStore.isLoadingPage else { return }
        let clipView = scrollView.contentView
        let docFrame = scrollView.documentView?.frame ?? .zero

        if isVerticalScroll {
            let visibleMaxY = clipView.bounds.origin.y + clipView.bounds.height
            guard docFrame.height - visibleMaxY < loadMoreThreshold else { return }
        } else {
            let visibleMaxX = clipView.bounds.origin.x + clipView.bounds.width
            guard docFrame.width - visibleMaxX < loadMoreThreshold else { return }
        }
        dataStore.loadNextPage()
    }
}
