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
    private var appInfoList: [(name: String, path: String, icon: NSImage?)] = []
    private var appButtons: [AppFilterButton] = []
    private var showAllApps = false

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

    func setAvailableApps(_ apps: [(name: String, path: String, icon: NSImage?)]) {
        let newAppNames = apps.map(\.name)
        let oldAppNames = appInfoList.map(\.name)
        let newAppPaths = apps.map(\.path)
        let oldAppPaths = appInfoList.map(\.path)
        guard newAppNames != oldAppNames || newAppPaths != oldAppPaths else { return }

        appInfoList = apps
        showAllApps = false
        rebuildButtons()
        layoutGrid()
    }

    func updateSelection(_ apps: Set<String>) {
        selectedApps = apps
        for button in appButtons {
            button.isSelected = apps.contains(button.appName)
        }
    }

    func updateIcon(_ icon: NSImage, forAppNamed appName: String, path: String) {
        guard let button = appButtons.first(where: {
            $0.appName == appName && $0.appPath == path
        }) else {
            return
        }

        button.updateIcon(icon)
        if let index = appInfoList.firstIndex(where: {
            $0.name == appName && $0.path == path
        }) {
            appInfoList[index].icon = icon
        }
    }

    // MARK: - Grid

    /// 仅在应用列表变化时调用：创建全部应用按钮并缓存，供展开/收起复用。
    private func rebuildButtons() {
        appButtons.removeAll()

        for appInfo in appInfoList {
            let button = AppFilterButton(
                icon: appInfo.icon,
                title: appInfo.name,
                path: appInfo.path
            )
            button.action = { [weak self] in
                self?.onAppToggle?(appInfo.name, appInfo.path)
            }
            button.isSelected = selectedApps.contains(appInfo.name)
            appButtons.append(button)
        }
    }

    private func layoutGrid() {
        guard !appButtons.isEmpty else {
            isHidden = true
            gridView.setItems(
                [
                    .init(button: expandButton, position: 8),
                    .init(button: collapseButton, position: 0),
                ],
                visible: []
            )
            return
        }

        isHidden = false

        let shouldShowMore = appButtons.count > 9
        let displayed: [AppFilterButton] = shouldShowMore && !showAllApps
            ? Array(appButtons.prefix(8))
            : appButtons

        var visibleButtons: [FilterButton] = displayed
        if shouldShowMore {
            visibleButtons.append(showAllApps ? collapseButton : expandButton)
        }

        let items = appButtons.enumerated().map {
            PersistentFilterGridView.Item(button: $0.element, position: $0.offset)
        } + [
            .init(button: expandButton, position: 8),
            .init(button: collapseButton, position: appButtons.count),
        ]
        gridView.setItems(
            items,
            visible: visibleButtons
        )
    }

    private func toggleShowAllApps() {
        showAllApps.toggle()
        layoutGrid()
    }
}
