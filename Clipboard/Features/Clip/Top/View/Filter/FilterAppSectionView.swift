//
//  FilterAppSectionView.swift
//  Clipboard
//
//  Created by crown on 2026/4/27
//
//  应用筛选区域：管理应用按钮的创建、展开/收起和选中状态
//

import AppKit

final class FilterAppSectionView: FilterSectionView {
    // MARK: - Callbacks

    var onAppToggle: ((Int64) -> Void)?

    // MARK: - State

    private var selectedApps: Set<Int64> = []
    private var appInfoList: [FilterAppInfo] = []
    private var appButtons: [AppFilterButton] = []
    private var showAllApps = false
    private var buttonPreparationTask: Task<Void, Never>?
    private var buttonPreparationGeneration = 0

    private let collapsedAppCount = 8
    private let uncollapsedAppLimit = 9
    private let preparationBatchSize = 8

    // MARK: - Views

    private let expandButton = FilterButton(
        icon: "chevron.down.circle",
        title: String(localized: .more)
    )
    private let collapseButton = FilterButton(
        icon: "chevron.up.circle",
        title: String(localized: .collapse)
    )

    // MARK: - Init

    init() {
        super.init(title: String(localized: .app))
        isHidden = true
        expandButton.onTap = { [weak self] in
            self?.toggleShowAllApps()
        }
        collapseButton.onTap = { [weak self] in
            self?.toggleShowAllApps()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Public API

    func setAvailableApps(_ apps: [FilterAppInfo]) {
        let newAppNames = apps.map(\.name)
        let oldAppNames = appInfoList.map(\.name)
        let newAppPaths = apps.map(\.path)
        let oldAppPaths = appInfoList.map(\.path)
        guard apps.map(\.id) != appInfoList.map(\.id)
            || newAppNames != oldAppNames || newAppPaths != oldAppPaths else { return }

        cancelButtonPreparation()
        appInfoList = apps
        showAllApps = false
        rebuildInitialButtons()
        layoutGrid()
    }

    func updateSelection(_ apps: Set<Int64>) {
        selectedApps = apps
        for button in appButtons {
            button.isSelected = apps.contains(button.appID)
        }
    }

    func updateIcon(_ icon: NSImage, forAppID id: Int64) {
        guard let index = appInfoList.firstIndex(where: {
            $0.id == id
        }) else {
            return
        }

        appInfoList[index].icon = icon
        if index < appButtons.count {
            appButtons[index].updateIcon(icon)
        }
    }

    func prepareRemainingApps() {
        guard buttonPreparationTask == nil,
              appButtons.count < appInfoList.count
        else {
            return
        }

        let generation = buttonPreparationGeneration
        buttonPreparationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if buttonPreparationGeneration == generation {
                    buttonPreparationTask = nil
                }
            }

            while appButtons.count < appInfoList.count {
                await Task.yield()
                guard !Task.isCancelled,
                      buttonPreparationGeneration == generation
                else {
                    return
                }

                let endIndex = min(
                    appButtons.count + preparationBatchSize,
                    appInfoList.count
                )
                for index in appButtons.count ..< endIndex {
                    appButtons.append(makeButton(for: appInfoList[index]))
                }
                layoutGrid()
            }
        }
    }

    // MARK: - Grid

    private func rebuildInitialButtons() {
        appButtons.removeAll()

        let initialCount = appInfoList.count > uncollapsedAppLimit
            ? collapsedAppCount
            : appInfoList.count
        for index in 0 ..< initialCount {
            appButtons.append(makeButton(for: appInfoList[index]))
        }
    }

    private func makeButton(for appInfo: FilterAppInfo) -> AppFilterButton {
        let button = AppFilterButton(
            id: appInfo.id,
            icon: appInfo.icon,
            title: appInfo.name,
            path: appInfo.path
        )
        button.onTap = { [weak self] in
            self?.onAppToggle?(appInfo.id)
        }
        button.isSelected = selectedApps.contains(appInfo.id)
        return button
    }

    private func layoutGrid() {
        let shouldShowMore = appInfoList.count > uncollapsedAppLimit
        let displayed: [AppFilterButton] = shouldShowMore && !showAllApps
            ? Array(appButtons.prefix(collapsedAppCount))
            : appButtons

        var visible: [FilterButton] = displayed
        if shouldShowMore, !displayed.isEmpty {
            visible.append(showAllApps ? collapseButton : expandButton)
        }
        setButtons(all: appButtons + [expandButton, collapseButton], visible: visible)
    }

    private func toggleShowAllApps() {
        if !showAllApps {
            finishPreparingApps()
        }
        showAllApps.toggle()
        layoutGrid()
    }

    private func finishPreparingApps() {
        guard appButtons.count < appInfoList.count else { return }

        cancelButtonPreparation()
        for index in appButtons.count ..< appInfoList.count {
            appButtons.append(makeButton(for: appInfoList[index]))
        }
    }

    private func cancelButtonPreparation() {
        buttonPreparationTask?.cancel()
        buttonPreparationTask = nil
        buttonPreparationGeneration &+= 1
    }
}
