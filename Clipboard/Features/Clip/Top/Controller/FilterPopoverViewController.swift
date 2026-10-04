//
//  FilterPopoverViewController.swift
//  Clipboard
//
//  Popover 视图控制器：管理筛选内容视图的生命周期与数据加载
//

import AppKit
import Combine

final class FilterPopoverViewController: NSViewController {
    // MARK: - Properties

    private weak var viewModel: TopBarViewModel?
    private var loadingTask: Task<Void, Never>?
    private var appSubscription: AnyCancellable?

    private var hasInitializedView = false
    private var isViewVisible = false

    // MARK: - Views

    private lazy var contentView: FilterPopoverContentView = .init()

    // MARK: - Init

    init(viewModel: TopBarViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Lifecycle

    override func loadView() {
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        initView()
        initBindings()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if !hasInitializedView {
            prepare()
        } else {
            loadData()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        isViewVisible = true
        contentView.appSection.prepareRemainingApps()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        isViewVisible = false
    }

    // MARK: - Public API

    func prepare() {
        loadViewIfNeeded()
        guard !hasInitializedView else { return }
        hasInitializedView = true
        loadData()
    }
}

// MARK: - Layout

extension FilterPopoverViewController {
    private func initView() {
        preferredContentSize = NSSize(width: 450, height: 320)
    }
}

// MARK: - Bindings

extension FilterPopoverViewController {
    private func initBindings() {
        appSubscription = SourceAppCache.shared.changes.sink { [weak self] in
            guard let self, isViewVisible else { return }
            loadData()
        }
        // 类型筛选回调
        contentView.typeSection.onTypeToggle = { [weak self] type in
            self?.viewModel?.toggleType(type)
            self?.updateContentViewState()
        }

        // 应用筛选回调
        contentView.appSection.onAppToggle = { [weak self] id in
            self?.viewModel?.toggleApp(id)
            self?.updateContentViewState()
        }

        // 标签筛选回调
        contentView.tagSection.onGroupToggle = { [weak self] groupId in
            self?.viewModel?.toggleGroupFilter(groupId)
            self?.updateContentViewState()
        }

        // 日期筛选回调
        contentView.dateSection.onDateFilterChange = { [weak self] dateFilter in
            self?.viewModel?.setDateFilter(dateFilter)
            self?.updateContentViewState()
        }
    }
}

// MARK: - State Management

extension FilterPopoverViewController {
    private func updateContentViewState() {
        guard let viewModel else { return }

        contentView.typeSection.updateSelection(viewModel.selectedTypes)
        contentView.appSection.updateSelection(viewModel.selectedAppIDs)
        contentView.tagSection.updateSelection(viewModel.selectedGroupIds)
        contentView.dateSection.updateSelection(viewModel.selectedDateFilter)
    }

    private func loadData() {
        loadingTask?.cancel()

        loadingTask = Task { @MainActor [weak self] in
            guard let self, viewModel != nil else { return }

            let rawAppInfo = SourceAppCache.shared.orderedApps
            guard !Task.isCancelled else { return }

            let appInfo = rawAppInfo.map { info in
                let icon = AppIconCache.shared.getCachedIcon(forAppID: info.id)
                return FilterAppInfo(
                    id: info.id,
                    name: info.name,
                    path: info.path,
                    icon: icon
                )
            }

            contentView.typeSection.setAvailableTypes([
                .color, .file, .image, .link, .string
            ])
            contentView.appSection.setAvailableApps(appInfo)
            if isViewVisible {
                contentView.appSection.prepareRemainingApps()
            }

            let userChips = CategoryChipStore.shared.chips.filter { !$0.isSystem }
            contentView.tagSection.setAvailableGroups(userChips)

            updateContentViewState()

            await loadMissingIcons(for: rawAppInfo)
        }
    }

    private func loadMissingIcons(for appInfo: [SourceApp]) async {
        await withTaskGroup(of: (Int64, NSImage).self) { group in
            var pending = appInfo.makeIterator()
            for _ in 0..<min(6, appInfo.count) {
                guard let app = pending.next() else { break }
                group.addTask {
                    let icon = await AppIconCache.shared.loadIcon(forAppID: app.id, path: app.path)
                    return (app.id, icon)
                }
            }
            while let (id, icon) = await group.next() {
                guard !Task.isCancelled else { group.cancelAll(); return }
                contentView.appSection.updateIcon(icon, forAppID: id)
                if let app = pending.next() {
                    group.addTask {
                        let icon = await AppIconCache.shared.loadIcon(forAppID: app.id, path: app.path)
                        return (app.id, icon)
                    }
                }
            }
        }
    }
}
