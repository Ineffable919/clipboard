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

    @State private var appInfoList: [(name: String, path: String)] = []
    @State private var isLoadingApps: Bool = false
    @State private var showAllApps: Bool = false
    @State private var tagTypes: [PasteModelType] = []

    private var displayedAppInfo: [(name: String, path: String)] {
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
        VStack(alignment: .leading, spacing: Const.space8) {
            Text("Type")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Const.space8),
                    GridItem(.flexible(), spacing: Const.space8),
                    GridItem(.flexible(), spacing: Const.space8),
                ],
                spacing: Const.space8,
            ) {
                ForEach(tagTypes, id: \.self) { type in
                    if type == .string {
                        textTypeButton()
                    } else {
                        let iconAndLabel = type.iconAndLabel
                        typeButton(
                            type: type,
                            icon: iconAndLabel.icon,
                            label: iconAndLabel.label,
                        )
                    }
                }
            }
        }
    }

    private func typeButton(type: PasteModelType, icon: String, label: String)
        -> some View
    {
        FilterButton(
            icon: {
                Image(systemName: icon)
                    .foregroundStyle(
                        topBarVM.selectedTypes.contains(type)
                            ? .white : .secondary,
                    )
            },
            label: label,
            isSelected: topBarVM.selectedTypes.contains(type),
            action: {
                topBarVM.toggleType(type)
            },
        )
    }

    private func textTypeButton() -> some View {
        FilterButton(
            icon: {
                Image(systemName: "text.document")
                    .foregroundStyle(
                        topBarVM.isTextTypeSelected()
                            ? .white : .secondary,
                    )
            },
            label: "文本",
            isSelected: topBarVM.isTextTypeSelected(),
            action: {
                topBarVM.toggleTextType()
            },
        )
    }

    // MARK: - App Section

    private var appSection: some View {
        VStack(alignment: .leading, spacing: Const.space8) {
            Text("App")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Const.space8),
                    GridItem(.flexible(), spacing: Const.space8),
                    GridItem(.flexible(), spacing: Const.space8),
                ],
                spacing: Const.space8,
            ) {
                ForEach(displayedAppInfo, id: \.name) { appInfo in
                    appButton(name: appInfo.name, path: appInfo.path)
                }

                if shouldShowMoreButton {
                    moreButton
                }
            }
        }
    }

    private func appButton(name: String, path: String) -> some View {
        FilterButton(
            icon: {
                if FileManager.default.fileExists(atPath: path) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: Const.space16))
                        .foregroundStyle(.secondary)
                }
            },
            label: name,
            isSelected: topBarVM.selectedAppNames.contains(name),
            action: {
                topBarVM.toggleApp(name)
            },
        )
    }

    private var moreButton: some View {
        FilterButton(
            icon: {
                Image(
                    systemName: showAllApps
                        ? "chevron.up.circle" : "chevron.down.circle",
                )
                .font(.system(size: Const.space16))
            },
            label: showAllApps ? "收起" : "更多",
            isSelected: false,
            action: {
                showAllApps.toggle()
            },
        )
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Const.space8) {
            Text("Date")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Const.space8),
                    GridItem(.flexible(), spacing: Const.space8),
                    GridItem(.flexible(), spacing: Const.space8),
                ],
                spacing: Const.space8,
            ) {
                ForEach(TopBarViewModel.DateFilterOption.allCases, id: \.self) {
                    option in
                    dateButton(option: option)
                }
            }
        }
    }

    private func dateButton(option: TopBarViewModel.DateFilterOption)
        -> some View
    {
        FilterButton(
            icon: {
                Image(systemName: "calendar")
                    .foregroundStyle(
                        topBarVM.selectedDateFilter == option
                            ? .white : .secondary,
                    )
            },
            label: option.displayName,
            isSelected: topBarVM.selectedDateFilter == option,
            action: {
                if topBarVM.selectedDateFilter == option {
                    topBarVM.setDateFilter(nil)
                } else {
                    topBarVM.setDateFilter(option)
                }
            },
        )
    }

    // MARK: - Clear Filters Button

    private var clearFiltersButton: some View {
        FilterButton(
            icon: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: Const.space16))
            },
            label: "清除筛选",
            isSelected: false,
            action: {
                topBarVM.clearAllFilters()
            },
        )
    }

    // MARK: - Helper Methods

    private func loadAppInfo() async {
        isLoadingApps = true
        async let info = PasteDataStore.main.getAllAppInfo()
        async let types = PasteDataStore.main.getAllTagTypes()

        let (appInfo, tagTypeList) = await (info, types)

        await MainActor.run {
            appInfoList = appInfo
            tagTypes = tagTypeList
            isLoadingApps = false
        }
    }
}
