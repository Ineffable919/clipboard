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
        rebuildButtons()
        layoutGrid()
    }

    func updateSelection(_ apps: Set<String>) {
        selectedApps = apps
        for button in appButtons {
            button.isSelected = apps.contains(button.appName)
        }
    }

    // MARK: - Grid

    /// 仅在应用列表变化时调用：创建全部应用按钮并缓存，供展开/收起复用。
    private func rebuildButtons() {
        appButtons.removeAll()

        for appInfo in appInfoList {
            let button = AppFilterButton(icon: appInfo.icon, title: appInfo.name)
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
            return
        }

        isHidden = false

        let shouldShowMore = appButtons.count > 9
        let displayed: [AppFilterButton] = shouldShowMore && !showAllApps
            ? Array(appButtons.prefix(8))
            : appButtons

        var buttons: [FilterButton] = displayed

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
        layoutGrid()
    }
}
