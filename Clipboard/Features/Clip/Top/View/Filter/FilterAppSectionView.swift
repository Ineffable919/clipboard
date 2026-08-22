//
//  FilterAppSectionView.swift
//  Clipboard
//
//  应用筛选区域：管理应用按钮的创建、布局、展开/收起和选中状态
//

import AppKit
import SnapKit

final class FilterAppSectionView: NSStackView {
    // MARK: - Callbacks

    var onAppToggle: ((String, String?) -> Void)?

    // MARK: - State

    private var selectedApps: Set<String> = []
    private var appInfoList: [FilterAppInfo] = []
    private var appButtons: [AppFilterButton] = []
    private var showAllApps = false
    private var buttonPreparationTask: Task<Void, Never>?
    private var buttonPreparationGeneration = 0

    private let collapsedAppCount = 8
    private let uncollapsedAppLimit = 9
    private let preparationBatchSize = 8

    // MARK: - Views

    private let titleLabel = NSTextField()
    private let gridContainer = NSView()
    private let gridView = PersistentFilterGridView()
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
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        isHidden = true
        orientation = .vertical
        alignment = .leading
        spacing = Const.space8

        titleLabel.stringValue = String(localized: .app)
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false

        addArrangedSubview(titleLabel)
        addArrangedSubview(gridContainer)

        gridContainer.addSubview(gridView)
        gridView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        expandButton.action = { [weak self] in
            self?.toggleShowAllApps()
        }
        collapseButton.action = { [weak self] in
            self?.toggleShowAllApps()
        }
    }

    // MARK: - Public API

    func setAvailableApps(_ apps: [FilterAppInfo]) {
        let newAppNames = apps.map(\.name)
        let oldAppNames = appInfoList.map(\.name)
        let newAppPaths = apps.map(\.path)
        let oldAppPaths = appInfoList.map(\.path)
        guard newAppNames != oldAppNames || newAppPaths != oldAppPaths else { return }

        cancelButtonPreparation()
        appInfoList = apps
        showAllApps = false
        rebuildInitialButtons()
        layoutGrid()
    }

    func updateSelection(_ apps: Set<String>) {
        selectedApps = apps
        for button in appButtons {
            button.isSelected = apps.contains(button.appName)
        }
    }

    func updateIcon(_ icon: NSImage, forAppNamed appName: String, path: String) {
        guard let index = appInfoList.firstIndex(where: {
            $0.name == appName && $0.path == path
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
            icon: appInfo.icon,
            title: appInfo.name,
            path: appInfo.path
        )
        button.action = { [weak self] in
            self?.onAppToggle?(appInfo.name, appInfo.path)
        }
        button.isSelected = selectedApps.contains(appInfo.name)
        return button
    }

    private func layoutGrid() {
        guard !appButtons.isEmpty else {
            isHidden = true
            gridView.setItems(
                [
                    .init(button: expandButton, position: collapsedAppCount),
                    .init(button: collapseButton, position: 0)
                ],
                visible: []
            )
            return
        }

        isHidden = false

        let shouldShowMore = appInfoList.count > uncollapsedAppLimit
        let displayed: [AppFilterButton] = shouldShowMore && !showAllApps
            ? Array(appButtons.prefix(collapsedAppCount))
            : appButtons

        var visibleButtons: [FilterButton] = displayed
        if shouldShowMore {
            visibleButtons.append(showAllApps ? collapseButton : expandButton)
        }

        let items = appButtons.enumerated().map {
            PersistentFilterGridView.Item(button: $0.element, position: $0.offset)
        } + [
            .init(button: expandButton, position: collapsedAppCount),
            .init(button: collapseButton, position: appInfoList.count)
        ]
        gridView.setItems(
            items,
            visible: visibleButtons
        )
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
