//
//  FilterPopoverView.swift
//  Clipboard
//
//  Created by crown on 2025/12/12.
//

import SwiftUI

struct FilterPopoverView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var topBarVM: TopBarViewModel

    @State private var appInfoList: [AppInfo] = []
    @State private var showAllApps: Bool = false
    @State private var tagTypes: [PasteModelType] = []

    // MARK: - 统一的三列网格布局

    private let threeColumnGrid = [
        GridItem(.flexible(), spacing: Const.space8),
        GridItem(.flexible(), spacing: Const.space8),
        GridItem(.flexible(), spacing: Const.space8),
    ]

    private var displayedAppInfo: [AppInfo] {
        let totalCount = appInfoList.count
        if totalCount <= 9 {
            return appInfoList
        } else {
            if showAllApps {
                return appInfoList
            } else {
                return Array(appInfoList.prefix(8))
            }
        }
    }

    private var shouldShowMoreButton: Bool {
        appInfoList.count > 9
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Const.space16) {
                if !tagTypes.isEmpty {
                    typeSection
                }

                if !appInfoList.isEmpty {
                    appSection
                }

                dateSection

                if topBarVM.hasActiveFilters {
                    clearFiltersButton
                }
            }
            .padding(Const.space16)
        }
        .frame(width: 480.0, height: 270.0)
        .focusEffectDisabled()
        .task {
            await loadAppInfo()
        }
    }

    // MARK: - Type Section

    private var typeSection: some View {
        filterSection(title: String(localized: .type)) {
            ForEach(tagTypes, id: \.self) { type in
                if type == .string {
                    textTypeButton()
                } else {
                    let iconAndLabel = type.iconAndLabel
                    FilterButton(
                        systemImage: iconAndLabel.icon,
                        label: iconAndLabel.label,
                        isSelected: topBarVM.selectedTypes.contains(type),
                        action: { topBarVM.toggleType(type) }
                    )
                }
            }
        }
    }

    private func textTypeButton() -> some View {
        let isSelected = topBarVM.isTextTypeSelected()

        return FilterButton(
            systemImage: "doc.text",
            label: String(localized: .text),
            isSelected: isSelected,
            action: { topBarVM.toggleTextType() }
        )
    }

    // MARK: - App Section

    private var appSection: some View {
        filterSection(title: String(localized: .app)) {
            ForEach(displayedAppInfo) { appInfo in
                appButton(appInfo: appInfo)
            }

            if shouldShowMoreButton {
                moreButton
            }
        }
    }

    private func appButton(appInfo: AppInfo) -> some View {
        FilterButton(
            icon: {
                if let icon = appInfo.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "questionmark.app.dashed")
                        .font(.system(size: Const.space16))
                        .foregroundStyle(.secondary)
                }
            },
            label: appInfo.name,
            isSelected: topBarVM.selectedAppNames.contains(appInfo.name),
            action: {
                topBarVM.toggleApp(appInfo.name, appPath: appInfo.path)
            }
        )
    }

    private var moreButton: some View {
        FilterButton(
            systemImage: showAllApps
                ? "chevron.up.circle" : "chevron.down.circle",
            label: String(localized: showAllApps ? .collapse : .more),
            isSelected: false,
            action: { showAllApps.toggle() }
        )
    }

    // MARK: - Date Section

    private var dateSection: some View {
        filterSection(title: String(localized: .date)) {
            ForEach(TopBarViewModel.DateFilterOption.allCases, id: \.self) {
                option in
                let isSelected = topBarVM.selectedDateFilter == option
                FilterButton(
                    systemImage: "calendar",
                    label: option.displayName,
                    isSelected: isSelected,
                    action: {
                        topBarVM.setDateFilter(isSelected ? nil : option)
                    }
                )
            }
        }
    }

    // MARK: - Clear Filters Button

    private var clearFiltersButton: some View {
        FilterButton(
            systemImage: "xmark.circle",
            label: String(localized: .clearFilters),
            isSelected: false,
            action: { topBarVM.clearAllFilters() }
        )
    }

    // MARK: - Reusable Components

    /// 通用筛选区块
    private func filterSection(
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Const.space8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: threeColumnGrid, spacing: Const.space8) {
                content()
            }
        }
    }

    // MARK: - Helper Methods

    private func loadAppInfo() async {
        guard appInfoList.isEmpty else { return }

        async let info = PasteDataStore.main.getAllAppInfo()
        async let types = PasteDataStore.main.getAllTagTypes()

        let (rawAppInfo, tagTypeList) = await (info, types)

        let appInfoWithIcons = await withTaskGroup(of: (Int, AppInfo).self) { group in
            for (index, info) in rawAppInfo.enumerated() {
                group.addTask {
                    let icon = await AppIconCache.shared.loadIcon(forPath: info.path)
                    return (index, AppInfo(name: info.name, path: info.path, icon: icon))
                }
            }

            var results: [(Int, AppInfo)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted(by: { $0.0 < $1.0 }).map(\.1)
        }

        appInfoList = appInfoWithIcons
        tagTypes = tagTypeList
    }
}

// MARK: - AppInfo Model

struct AppInfo: Identifiable {
    let id: String
    let name: String
    let path: String
    let icon: NSImage?

    nonisolated init(name: String, path: String, icon: NSImage?) {
        id = name
        self.name = name
        self.path = path
        self.icon = icon
    }
}
