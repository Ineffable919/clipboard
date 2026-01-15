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
                DisplayModeRow(displayMode: Binding(
                    get: { displayMode },
                    set: { displayMode = $0 }
                ))

                if displayMode == .floating {
                    WindowPositionRow(windowPosition: Binding(
                        get: { windowPosition },
                        set: { windowPosition = $0 }
                    ))
                }
            }
            .settingsStyle()

            Text("背景")
                .font(.headline)
                .fontWeight(.medium)

            VStack(spacing: 0) {
                if #available(macOS 26.0, *) {
                    HStack {
                        Text("类型")
                        Spacer()
                        HStack(alignment: .top, spacing: Const.space4) {
                            Image(
                                systemName: backgroundType == .liquid
                                    ? "record.circle.fill" : "circle"
                            )
                            .foregroundStyle(
                                backgroundType == .liquid
                                    ? Color.accentColor : .secondary
                            )
                            .font(.system(size: Const.space16))
                            .onTapGesture {
                                backgroundType = .liquid
                            }
                            Text("液态玻璃")
                        }
                        HStack(alignment: .top, spacing: Const.space4) {
                            Image(
                                systemName: backgroundType == .frosted
                                    ? "record.circle.fill" : "circle"
                            )
                            .foregroundStyle(
                                backgroundType == .frosted
                                    ? Color.accentColor : .secondary
                            )
                            .font(.system(size: Const.space16))
                            .onTapGesture {
                                backgroundType = .frosted
                            }
                            Text("毛玻璃")
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
            Text("玻璃材质")
                .font(.body)
            Spacer()
            HStack(spacing: Const.space8) {
                Text("透明")
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
                Text("模糊")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 240.0)
        }
        .padding(.top, Const.space16)
    }
}

// MARK: - 外观设置行

struct AppearanceSettingsRow: View {
    @AppStorage(PrefKey.appearance.rawValue) private var appearanceRaw: Int = 0

    private var selectedAppearance: AppearanceMode {
        get { .init(rawValue: appearanceRaw) ?? .system }
        nonmutating set { appearanceRaw = newValue.rawValue }
    }

    private let options: [(mode: AppearanceMode, icon: String)] = [
        (.system, "circle.lefthalf.filled.righthalf.striped.horizontal"),
        (.light, "sun.max"),
        (.dark, "moon"),
    ]

    var body: some View {
        HStack {
            Text("外观")
                .font(.body)
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
        .onAppear {
            applyAppearance(selectedAppearance)
        }
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        DispatchQueue.main.async {
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
            Text("显示模式")
            Spacer()
            HStack(spacing: Const.space16) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    HStack(spacing: Const.space4) {
                        Image(
                            systemName: displayMode == mode
                                ? "record.circle.fill" : "circle"
                        )
                        .foregroundStyle(
                            displayMode == mode
                                ? Color.accentColor : .secondary
                        )
                        .font(.system(size: Const.space16))
                        .onTapGesture {
                            displayMode = mode
                        }
                        Text(mode.title)
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
            Text("窗口位置")
                .font(.body)
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

#Preview {
    AppearanceSettingsView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
