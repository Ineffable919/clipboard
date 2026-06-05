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
            loadDataFromCache()
            hasInitializedView = true
        } else {
            updateFromCache()
        }
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

    private func loadDataFromCache() {
        loadingTask?.cancel()

        loadingTask = Task { @MainActor [weak self] in
            guard let self, let viewModel else { return }

            await viewModel.loadAppPathCache()

            async let appInfoTask = loadAppInfoWithIcons()
            async let typesTask = PasteMetadataCache.shared.getAllTagTypes()

            let (appInfo, types) = await (appInfoTask, typesTask)

            contentView.typeSection.setAvailableTypes(types)
            contentView.appSection.setAvailableApps(appInfo)

            let userChips = CategoryChipStore.shared.chips.filter { !$0.isSystem }
            contentView.tagSection.setAvailableGroups(userChips)

            updateContentViewState()
        }
    }

    private func updateFromCache() {
        loadingTask?.cancel()

        loadingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let types = await PasteMetadataCache.shared.getAllTagTypes()
            let rawAppInfo = await PasteMetadataCache.shared.getAllAppInfo()

            let appInfo = rawAppInfo.map { info in
                let icon = AppIconCache.shared.getCachedIcon(forPath: info.path)
                return (name: info.name, path: info.path, icon: icon)
            }

            contentView.typeSection.setAvailableTypes(types)
            contentView.appSection.setAvailableApps(appInfo)

            let userChips = CategoryChipStore.shared.chips.filter { !$0.isSystem }
            contentView.tagSection.setAvailableGroups(userChips)

            updateContentViewState()
        }
    }

    private func loadAppInfoWithIcons() async -> [(name: String, path: String, icon: NSImage?)] {
        let rawAppInfo = await PasteMetadataCache.shared.getAllAppInfo()

        return await withTaskGroup(
            of: (Int, (name: String, path: String, icon: NSImage?)).self
        ) { group in
            for (index, info) in rawAppInfo.enumerated() {
                group.addTask {
                    let icon = await AppIconCache.shared.loadIcon(forPath: info.path)
                    return (index, (name: info.name, path: info.path, icon: icon))
                }
            }

            var results: [(Int, (name: String, path: String, icon: NSImage?))] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted(by: { $0.0 < $1.0 }).map(\.1)
        }
    }
}
