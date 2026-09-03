//
//  FilterPopoverViewController.swift
//  Clipboard
//
//  Popover 视图控制器：管理筛选内容视图的生命周期与数据加载
//

import AppKit

final class FilterPopoverViewController: NSViewController {
    // MARK: - Properties

    private weak var viewModel: TopBarViewModel?
    private var loadingTask: Task<Void, Never>?

    private var hasInitializedView = false
    private var hasAppeared = false
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
        } else if hasAppeared {
            loadData()
        }
        hasAppeared = true
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
        // 类型筛选回调
        contentView.typeSection.onTypeToggle = { [weak self] type in
            self?.viewModel?.toggleType(type)
            self?.updateContentViewState()
        }

        // 应用筛选回调
        contentView.appSection.onAppToggle = { [weak self] appName, appPath in
            self?.viewModel?.toggleApp(appName, appPath: appPath)
            self?.updateContentViewState()
        }

        // 标签筛选回调
        contentView.tagSection.onGroupToggle = { [weak self] groupId in
            self?.viewModel?.setGroupFilter(groupId)
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
        contentView.appSection.updateSelection(viewModel.selectedAppNames)
        contentView.tagSection.updateSelection(viewModel.selectedGroupId)
        contentView.dateSection.updateSelection(viewModel.selectedDateFilter)
    }

    private func loadData() {
        loadingTask?.cancel()

        loadingTask = Task { @MainActor [weak self] in
            guard let self, let viewModel else { return }

            async let appPathTask: Void = viewModel.loadAppPathCache()
            async let appInfoTask = PasteMetadataCache.shared.getAllAppInfo()

            let (rawAppInfo, _) = await (
                appInfoTask,
                appPathTask
            )
            guard !Task.isCancelled else { return }

            let appInfo = rawAppInfo.map { info in
                let icon = AppIconCache.shared.getCachedIcon(forPath: info.path)
                return FilterAppInfo(
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

    private func loadMissingIcons(
        for appInfo: [(name: String, path: String)]
    ) async {
        let missingAppInfo = appInfo.filter {
            AppIconCache.shared.getCachedIcon(forPath: $0.path) == nil
        }
        let maximumConcurrentLoads = 6

        await withTaskGroup(
            of: (name: String, path: String, icon: NSImage).self
        ) { group in
            var nextIndex = missingAppInfo.startIndex

            for _ in 0 ..< min(maximumConcurrentLoads, missingAppInfo.count) {
                let info = missingAppInfo[nextIndex]
                nextIndex = missingAppInfo.index(after: nextIndex)
                group.addTask {
                    let icon = await AppIconCache.shared.loadIcon(forPath: info.path)
                    return (name: info.name, path: info.path, icon: icon)
                }
            }

            while let result = await group.next() {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return
                }
                contentView.appSection.updateIcon(
                    result.icon,
                    forAppNamed: result.name,
                    path: result.path
                )

                if nextIndex < missingAppInfo.endIndex {
                    let info = missingAppInfo[nextIndex]
                    nextIndex = missingAppInfo.index(after: nextIndex)
                    group.addTask {
                        let icon = await AppIconCache.shared.loadIcon(forPath: info.path)
                        return (name: info.name, path: info.path, icon: icon)
                    }
                }
            }
        }
    }
}
