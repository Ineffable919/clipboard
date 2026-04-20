//
//  FilterPopoverContentView.swift
//  Clipboard
//
//  Popover 内容视图，包含类型、应用和日期筛选区域
//

import AppKit
import SnapKit

// MARK: - FlippedView

private final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

final class FilterPopoverContentView: NSView {
    // MARK: - Properties

    private let scrollView = NSScrollView()
    private let contentView = FlippedView()
    private let mainStack = NSStackView()

    // 类型筛选区域
    private let typeSection = NSStackView()
    private let typeLabel = NSTextField()
    private let typeGridContainer = NSView()
    private var typeButtons: [PasteModelType: FilterButton] = [:]

    // 应用筛选区域
    private let appSection = NSStackView()
    private let appLabel = NSTextField()
    private let appGridContainer = NSView()
    private var appButtons: [AppFilterButton] = []
    private var moreButton: FilterButton?
    private var showAllApps = false

    // 日期筛选区域
    private let dateSection = NSStackView()
    private let dateLabel = NSTextField()
    private let dateGridContainer = NSView()
    private var dateButtons: [DateFilterOption: FilterButton] = [:]

    var onTypeToggle: ((PasteModelType) -> Void)?
    var onAppToggle: ((String, String?) -> Void)?
    var onDateFilterChange: ((DateFilterOption?) -> Void)?

    // 当前选中状态
    private var selectedTypes: Set<PasteModelType> = []
    private var selectedApps: Set<String> = []
    private var selectedDateFilter: DateFilterOption?

    // 应用信息列表
    private var appInfoList: [(name: String, path: String, icon: NSImage?)] = []
    private var availableTypes: [PasteModelType] = []

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
        wantsLayer = true

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true

        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = contentView
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        addSubview(scrollView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.width.equalTo(scrollView)
        }

        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = Const.space16
        contentView.addSubview(mainStack)

        mainStack.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Const.space6)
            make.leading.trailing.bottom.equalToSuperview().inset(Const.space16)
        }

        setupTypeSection()
        setupAppSection()
        setupDateSection()

        mainStack.addArrangedSubview(typeSection)
        mainStack.addArrangedSubview(appSection)
        mainStack.addArrangedSubview(dateSection)

        typeSection.isHidden = true
        appSection.isHidden = true

        rebuildDateGrid()
    }

    private func setupTypeSection() {
        typeSection.orientation = .vertical
        typeSection.alignment = .leading
        typeSection.spacing = Const.space8

        typeLabel.stringValue = String(localized: .type)
        typeLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        typeLabel.textColor = .secondaryLabelColor
        typeLabel.isBordered = false
        typeLabel.drawsBackground = false
        typeLabel.isEditable = false
        typeLabel.isSelectable = false
        typeSection.addArrangedSubview(typeLabel)

        typeSection.addArrangedSubview(typeGridContainer)
    }

    private func setupAppSection() {
        appSection.orientation = .vertical
        appSection.alignment = .leading
        appSection.spacing = Const.space8

        appLabel.stringValue = String(localized: .app)
        appLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        appLabel.textColor = .secondaryLabelColor
        appLabel.isBordered = false
        appLabel.drawsBackground = false
        appLabel.isEditable = false
        appLabel.isSelectable = false
        appSection.addArrangedSubview(appLabel)

        appSection.addArrangedSubview(appGridContainer)
    }

    private func setupDateSection() {
        dateSection.orientation = .vertical
        dateSection.alignment = .leading
        dateSection.spacing = Const.space8

        dateLabel.stringValue = String(localized: .date)
        dateLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        dateLabel.textColor = .secondaryLabelColor
        dateLabel.isBordered = false
        dateLabel.drawsBackground = false
        dateLabel.isEditable = false
        dateLabel.isSelectable = false
        dateSection.addArrangedSubview(dateLabel)

        dateSection.addArrangedSubview(dateGridContainer)
    }

    // MARK: - Grid Layout

    private func rebuildTypeGrid() {
        typeGridContainer.subviews.forEach { $0.removeFromSuperview() }
        typeButtons.removeAll()

        guard !availableTypes.isEmpty else {
            typeSection.isHidden = true
            return
        }

        typeSection.isHidden = false

        var buttons: [FilterButton] = []
        for type in availableTypes {
            let button: FilterButton
            if type == .string {
                // 文本按钮同时代表 .string 和 .rich，选中态任一存在即高亮
                button = FilterButton(icon: "doc.text", title: "文本")
                button.action = { [weak self] in
                    self?.handleTextTypeToggle()
                }
                button.isSelected = selectedTypes.contains(.string) || selectedTypes.contains(.rich)
            } else if type == .rich {
                // .rich 由文本按钮统一控制，不单独渲染
                continue
            } else {
                let (icon, label) = type.iconAndLabel
                button = FilterButton(icon: icon, title: label)
                button.action = { [weak self] in
                    self?.handleTypeToggle(type)
                }
                button.isSelected = selectedTypes.contains(type)
            }
            typeButtons[type] = button
            buttons.append(button)
        }

        layoutThreeColumnGrid(buttons: buttons, in: typeGridContainer)
    }

    private func rebuildAppGrid() {
        appGridContainer.subviews.forEach { $0.removeFromSuperview() }
        appButtons.removeAll()
        moreButton = nil

        guard !appInfoList.isEmpty else {
            appSection.isHidden = true
            return
        }

        appSection.isHidden = false

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
                self?.handleAppToggle(appInfo.name, appPath: appInfo.path)
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

        layoutThreeColumnGrid(buttons: buttons, in: appGridContainer)
    }

    private func rebuildDateGrid() {
        dateGridContainer.subviews.forEach { $0.removeFromSuperview() }
        dateButtons.removeAll()

        var buttons: [FilterButton] = []
        for option in DateFilterOption.allCases {
            let button = FilterButton(icon: "calendar", title: option.displayName)
            button.action = { [weak self] in
                self?.handleDateFilterChange(option)
            }
            button.isSelected = selectedDateFilter == option
            dateButtons[option] = button
            buttons.append(button)
        }

        layoutThreeColumnGrid(buttons: buttons, in: dateGridContainer)
    }

    /// 三列网格布局
    private func layoutThreeColumnGrid(buttons: [FilterButton], in container: NSView) {
        container.subviews.forEach { $0.removeFromSuperview() }

        let columnCount = 3
        let spacing = Const.space8
        let buttonWidth: CGFloat = 140
        let buttonHeight: CGFloat = 30

        let gridView = NSGridView()
        gridView.rowSpacing = spacing
        gridView.columnSpacing = spacing
        gridView.xPlacement = .leading
        gridView.yPlacement = .center

        container.addSubview(gridView)
        gridView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        var currentRow: [NSView] = []
        for (index, button) in buttons.enumerated() {
            button.snp.makeConstraints { make in
                make.width.equalTo(buttonWidth)
                make.height.equalTo(buttonHeight)
            }

            currentRow.append(button)

            if currentRow.count == columnCount || index == buttons.count - 1 {
                while currentRow.count < columnCount {
                    let spacer = NSView()
                    spacer.snp.makeConstraints { make in
                        make.width.equalTo(buttonWidth)
                        make.height.equalTo(buttonHeight)
                    }
                    currentRow.append(spacer)
                }

                gridView.addRow(with: currentRow)
                currentRow.removeAll()
            }
        }

        container.snp.remakeConstraints { make in
            make.width.equalToSuperview()
        }
    }

    // MARK: - Public Methods

    func updateTypeSelection(_ types: Set<PasteModelType>) {
        selectedTypes = types
        for (type, button) in typeButtons {
            if type == .string {
                button.isSelected = types.contains(.string) || types.contains(.rich)
            } else {
                button.isSelected = types.contains(type)
            }
        }
    }

    func updateAppSelection(_ apps: Set<String>) {
        selectedApps = apps
        for button in appButtons {
            button.isSelected = apps.contains(button.appName)
        }
    }

    func updateDateSelection(_ dateFilter: DateFilterOption?) {
        selectedDateFilter = dateFilter
        for (option, button) in dateButtons {
            button.isSelected = option == dateFilter
        }
    }

    func setAvailableTypes(_ types: [PasteModelType]) {
        availableTypes = types
        rebuildTypeGrid()
    }

    func setAvailableApps(_ apps: [(name: String, path: String, icon: NSImage?)]) {
        appInfoList = apps
        showAllApps = false
        rebuildAppGrid()
    }

    // MARK: - Actions

    private func handleTypeToggle(_ type: PasteModelType) {
        onTypeToggle?(type)
    }

    /// 文本按钮同时 toggle .string 和 .rich
    private func handleTextTypeToggle() {
        onTypeToggle?(.string)
        onTypeToggle?(.rich)
    }

    private func handleAppToggle(_ appName: String, appPath: String) {
        onAppToggle?(appName, appPath)
    }

    private func handleDateFilterChange(_ option: DateFilterOption) {
        if selectedDateFilter == option {
            onDateFilterChange?(nil)
        } else {
            onDateFilterChange?(option)
        }
    }

    private func toggleShowAllApps() {
        showAllApps.toggle()
        rebuildAppGrid()
    }
}

// MARK: - AppFilterButton

private final class AppFilterButton: FilterButton {
    let appName: String

    init(icon: NSImage?, title: String) {
        appName = title
        super.init(icon: nil, title: title)

        if let appIcon = icon {
            setupAppIcon(appIcon)
        }
    }

    private func setupAppIcon(_ icon: NSImage) {
        let iconView = NSImageView()
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyDown
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
        stack.insertArrangedSubview(iconView, at: 0)
    }
}
