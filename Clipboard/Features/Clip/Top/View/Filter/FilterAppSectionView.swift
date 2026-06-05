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
    private var moreButton: FilterButton?
    private var showAllApps = false

    // MARK: - Views

    private let titleLabel = NSTextField()
    private let gridContainer = NSView()

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
    }

    // MARK: - Public API

    func setAvailableApps(_ apps: [(name: String, path: String, icon: NSImage?)]) {
        let newAppNames = apps.map(\.name)
        let oldAppNames = appInfoList.map(\.name)
        guard newAppNames != oldAppNames else { return }

        appInfoList = apps
        showAllApps = false
        rebuildGrid()
    }

    func updateSelection(_ apps: Set<String>) {
        selectedApps = apps
        for button in appButtons {
            button.isSelected = apps.contains(button.appName)
        }
    }

    // MARK: - Grid

    private func rebuildGrid() {
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        appButtons.removeAll()
        moreButton = nil

        guard !appInfoList.isEmpty else {
            isHidden = true
            return
        }

        isHidden = false

        let totalCount = appInfoList.count
        let shouldShowMore = totalCount > 9

        // 根据当前展开状态决定显示多少条
        let displayedApps = shouldShowMore && !showAllApps
            ? Array(appInfoList.prefix(8))
            : appInfoList

        var buttons: [FilterButton] = []

        for appInfo in displayedApps {
            let button = AppFilterButton(icon: appInfo.icon, title: appInfo.name)
            button.action = { [weak self] in
                self?.onAppToggle?(appInfo.name, appInfo.path)
            }
            button.isSelected = selectedApps.contains(appInfo.name)
            appButtons.append(button)
            buttons.append(button)
        }

        if shouldShowMore {
            let more = FilterButton(
                icon: showAllApps ? "chevron.up.circle" : "chevron.down.circle",
                title: showAllApps ? String(localized: .collapse) : String(localized: .more)
            )
            more.action = { [weak self] in
                self?.toggleShowAllApps()
            }
            moreButton = more
            buttons.append(more)
        }

        FilterGridLayout.layoutThreeColumnGrid(buttons: buttons, in: gridContainer)
    }

    private func toggleShowAllApps() {
        showAllApps.toggle()
        rebuildGrid()
    }
}
