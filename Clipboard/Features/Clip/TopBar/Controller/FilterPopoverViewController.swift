//
//  FilterPopoverViewController.swift
//  Clipboard
//
//  Popover 视图控制器，管理筛选内容视图的生命周期
//

import AppKit

final class FilterPopoverViewController: NSViewController {
    // MARK: - Properties

    private weak var viewModel: TopBarViewModel?
    private var loadingTask: Task<Void, Never>?

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
        refreshState()
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
        contentView.onTypeToggle = { [weak self] type in
            self?.viewModel?.toggleType(type)
            self?.updateContentViewState()
        }

        // 应用筛选回调
        contentView.onAppToggle = { [weak self] appName, appPath in
            self?.viewModel?.toggleApp(appName, appPath: appPath)
            self?.updateContentViewState()
        }

        // 日期筛选回调
        contentView.onDateFilterChange = { [weak self] dateFilter in
            self?.viewModel?.setDateFilter(dateFilter)
            self?.updateContentViewState()
        }
    }
}

// MARK: - State Management

extension FilterPopoverViewController {
    private func updateContentViewState() {
        guard let viewModel else { return }

        contentView.updateTypeSelection(viewModel.selectedTypes)
        contentView.updateAppSelection(viewModel.selectedAppNames)
        contentView.updateDateSelection(viewModel.selectedDateFilter)
    }

    private func refreshState() {
        loadData()
        updateContentViewState()
    }

    private func loadData() {
        loadingTask?.cancel()

        loadingTask = Task { @MainActor [weak self] in
            guard let self, let viewModel else { return }

            await viewModel.loadAppPathCache()

            async let appInfoTask = loadAppInfoWithIcons()
            async let typesTask = PasteMetadataCache.shared.getAllTagTypes()

            let (appInfo, types) = await (appInfoTask, typesTask)

            contentView.setAvailableTypes(types)
            contentView.setAvailableApps(appInfo)

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
