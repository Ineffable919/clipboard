//
//  AppearanceSettingsView.swift
//  Clipboard
//
//  Created by crown on 2025/12/05.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.colorScheme) var colorScheme

    @AppStorage(PrefKey.backgroundType.rawValue) private var backgroundTypeRaw:
        Int = 0
    @AppStorage(PrefKey.displayMode.rawValue) private var displayModeRaw: Int = 0
    @AppStorage(PrefKey.windowPosition.rawValue) private var windowPositionRaw: Int = 0

    private var backgroundType: BackgroundType {
        get { .init(rawValue: backgroundTypeRaw) ?? .liquid }
        nonmutating set { backgroundTypeRaw = newValue.rawValue }
    }

    private var displayMode: DisplayMode {
        get { .init(rawValue: displayModeRaw) ?? .drawer }
        nonmutating set { displayModeRaw = newValue.rawValue }
    }

    private var windowPosition: WindowPositionMode {
        get { .init(rawValue: windowPositionRaw) ?? .center }
        nonmutating set { windowPositionRaw = newValue.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Const.space16) {
            AppearanceSettingsRow()
                .settingsStyle()

            VStack(spacing: 0) {
                DisplayModeRow(
                    displayMode: Binding(
                        get: { displayMode },
                        set: { displayMode = $0 }
                    )
                )

                if displayMode == .floating {
                    WindowPositionRow(
                        windowPosition: Binding(
                            get: { windowPosition },
                            set: { windowPosition = $0 }
                        )
                    )
                }
            }
            .settingsStyle()

            Text(.settingAppearanceBackgroundSectionTitle)
                .font(.headline)
                .bold()

            VStack(spacing: 0) {
                if #available(macOS 26.0, *) {
                    HStack {
                        Text(.settingAppearanceBackgroundTypeLabel)
                        Spacer()
                        BackgroundTypeOptionButton(
                            title: .settingAppearanceBackgroundTypeLiquid,
                            isSelected: backgroundType == .liquid
                        ) {
                            backgroundType = .liquid
                        }
                        BackgroundTypeOptionButton(
                            title: .settingAppearanceBackgroundTypeFrosted,
                            isSelected: backgroundType == .frosted
                        ) {
                            backgroundType = .frosted
                        }
                    }
                }

                if #available(macOS 26.0, *) {
                    if backgroundType == .frosted {
                        GlassMaterialSlider()
                    }
                } else {
                    GlassMaterialSlider()
                }
            }
            .padding(.horizontal, Const.space16)
            .padding(.vertical, Const.space8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .settingsStyle()
        }
        .padding(Const.space24)
        .frame(
            maxWidth: .infinity,
            maxHeight: Const.settingHeight,
            alignment: .topLeading
        )
    }
}

// MARK: - 玻璃材质滑块

struct GlassMaterialSlider: View {
    @AppStorage(PrefKey.glassMaterial.rawValue)
    private var glassMaterialRaw: Int = 2

    private var glassMaterial: Double {
        get { Double(glassMaterialRaw) }
        nonmutating set { glassMaterialRaw = Int(newValue) }
    }

    private var range: ClosedRange<Double> {
        if #available(macOS 26.0, *) {
            0 ... 4
        } else {
            0 ... 3
        }
    }

    var body: some View {
        HStack {
            Text(.settingAppearanceGlassMaterialLabel)
            Spacer()
            HStack(spacing: Const.space8) {
                Text(.settingAppearanceGlassMaterialTransparent)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if #available(macOS 26.0, *) {
                    Slider(
                        value: Binding(
                            get: { glassMaterial },
                            set: { glassMaterial = $0 }
                        ),
                        in: range,
                        step: 1
                    )
                    .tint(.accentColor)
                } else {
                    Slider(
                        value: Binding(
                            get: { glassMaterial },
                            set: { glassMaterial = $0 }
                        ),
                        in: range
                    )
                    .tint(.accentColor)
                }
                Text(.settingAppearanceGlassMaterialBlurred)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 240.0)
        }
        .padding(.top, Const.space16)
    }
}

// MARK: - 语言与外观设置行

struct AppearanceSettingsRow: View {
    @AppStorage(PrefKey.appearance.rawValue) private var appearanceRaw: Int = 0
    @AppStorage(PrefKey.appLanguage.rawValue) private var languageRaw: String =
        AppLanguage.zhHans.rawValue
    @State private var pendingLanguage: AppLanguage? = nil

    private var selectedAppearance: AppearanceMode {
        get { .init(rawValue: appearanceRaw) ?? .system }
        nonmutating set { appearanceRaw = newValue.rawValue }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .zhHans
    }

    private let options: [(mode: AppearanceMode, icon: String)] = [
        (.system, "circle.lefthalf.filled.righthalf.striped.horizontal"),
        (.light, "sun.max"),
        (.dark, "moon"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 语言
            HStack {
                Text(.settingLanguage)
                Spacer()
                Picker(
                    selection: Binding(
                        get: { selectedLanguage },
                        set: { newValue in
                            guard newValue != selectedLanguage else { return }
                            pendingLanguage = newValue
                        }
                    ),
                    label: EmptyView()
                ) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.title).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .buttonStyle(.borderless)
            }
            .padding(.vertical, Const.space8)
            .padding(.horizontal, Const.space16)

            // 外观
            HStack {
                Text(.settingAppearanceModeLabel)
                Spacer()
                Picker(
                    "",
                    selection: Binding(
                        get: { selectedAppearance },
                        set: { newValue in
                            selectedAppearance = newValue
                            applyAppearance(newValue)
                        }
                    )
                ) {
                    ForEach(options, id: \.mode) { option in
                        HStack {
                            Image(systemName: option.icon)
                            Text(option.mode.title)
                        }
                        .tag(option.mode)
                    }
                }
                .pickerStyle(.menu)
                .buttonStyle(.borderless)
            }
            .padding(.vertical, Const.space8)
            .padding(.horizontal, Const.space16)
        }
        .onAppear {
            applyAppearance(selectedAppearance)
        }
        .alert(
            Text(.settingLanguageRestartConfirmTitle),
            isPresented: Binding(
                get: { pendingLanguage != nil },
                set: { if !$0 { pendingLanguage = nil } }
            )
        ) {
            Button(.commonCancel, role: .cancel) {
                pendingLanguage = nil
            }
            Button(.commonConfirm) {
                guard let lang = pendingLanguage else { return }
                languageRaw = lang.rawValue
                _ = lang.apply()
                NSApplication.shared.relaunch()
            }
        } message: {
            Text(.settingLanguageRestartConfirmMessage)
        }
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        Task { @MainActor in
            let targetAppearance: NSAppearance? =
                switch mode {
                case .system:
                    nil
                case .light:
                    NSAppearance(named: .aqua)
                case .dark:
                    NSAppearance(named: .darkAqua)
                }

            if NSApp.appearance != targetAppearance {
                NSApp.appearance = targetAppearance
            }
        }
    }
}

// MARK: - 显示模式行

struct DisplayModeRow: View {
    @Binding var displayMode: DisplayMode

    var body: some View {
        HStack {
            Text(.settingAppearanceDisplayModeLabel)
            Spacer()
            HStack(spacing: Const.space16) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    BackgroundTypeOptionButton(
                        title: mode.title,
                        isSelected: displayMode == mode
                    ) {
                        displayMode = mode
                    }
                }
            }
        }
        .padding(.vertical, Const.space8)
        .padding(.horizontal, Const.space16)
    }
}

// MARK: - 窗口位置行

struct WindowPositionRow: View {
    @Binding var windowPosition: WindowPositionMode

    var body: some View {
        HStack {
            Text(.settingAppearanceWindowPositionLabel)
            Spacer()
            Picker(
                "",
                selection: $windowPosition
            ) {
                ForEach(WindowPositionMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, Const.space8)
        .padding(.horizontal, Const.space16)
    }
}

struct BackgroundTypeOptionButton: View {
    let title: LocalizedStringResource
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Const.space4) {
                Image(systemName: isSelected ? "record.circle.fill" : "circle")
                    .foregroundStyle(
                        isSelected ? Color.accentColor : .secondary
                    )
                    .font(.system(size: Const.space16))
                Text(title)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppearanceSettingsView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
