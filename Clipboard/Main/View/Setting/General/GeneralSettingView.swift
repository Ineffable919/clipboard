//
//  GeneralSettingView.swift
//  Clipboard
//
//  Created by crown on 2025/10/28.
//

import SwiftUI

// MARK: - 通用设置视图

struct GeneralSettingView: View {
    @Environment(\.colorScheme) var colorScheme

    @State private var launchAtLogin = PasteUserDefaults.onStart
    @State private var soundEnabled = PasteUserDefaults.soundEnabled
    @State private var selectedPasteTarget: PasteTargetMode =
        PasteUserDefaults.pasteDirect ? .toApp : .toClipboard
    @State private var pasteAsPlainText = PasteUserDefaults.pasteOnlyText
    @State private var selectedHistoryTimeUnit: HistoryTimeUnit =
        .init(rawValue: PasteUserDefaults.historyTime)

    private var db: PasteDataStore = .main

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    SettingToggleRow(
                        title: "登录时打开",
                        isOn: $launchAtLogin,
                    )
                    .onChange(of: launchAtLogin) { _, newValue in
                        PasteUserDefaults.onStart = newValue
                        LaunchAtLoginHelper.shared.setEnabled(newValue)
                    }

                    Divider()

                    SettingToggleRow(
                        title: "音效",
                        isOn: $soundEnabled,
                    )
                    .onChange(of: soundEnabled) { _, newValue in
                        PasteUserDefaults.soundEnabled = newValue
                    }

                    Divider()

                    AppearanceSettingsRow()
                }
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .fill(
                            colorScheme == .light
                                ? Const.lightBackground : Const.darkBackground,
                        ),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1),
                )

                Text("粘贴项目")
                    .font(.headline)

                // 粘贴项目设置
                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 4) {
                        ForEach(PasteTargetMode.allCases, id: \.rawValue) {
                            mode in
                            PasteTargetModeRow(
                                mode: mode,
                                isSelected: selectedPasteTarget == mode,
                                onSelect: { selectedPasteTarget = mode },
                            )
                        }
                    }
                    .onChange(of: selectedPasteTarget) { _, newValue in
                        PasteUserDefaults.pasteDirect = (newValue == .toApp)
                    }

                    Divider()

                    PlainTextPasteRow(isEnabled: $pasteAsPlainText)
                        .onChange(of: pasteAsPlainText) { _, newValue in
                            PasteUserDefaults.pasteOnlyText = newValue
                        }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .fill(
                            colorScheme == .light
                                ? Const.lightBackground : Const.darkBackground,
                        ),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1),
                )

                HStack {
                    Text("保留历史")
                        .font(.headline)
                    Image(systemName: "exclamationmark.circle")
                        .help("每天仅删除一次")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HistoryTimeSlider(
                        selectedTimeUnit: $selectedHistoryTimeUnit,
                    )
                    .onChange(of: selectedHistoryTimeUnit) { _, newValue in
                        PasteUserDefaults.historyTime = newValue.rawValue
                    }

                    HStack {
                        Spacer()
                        Button("删除历史") {
                            db.clearAllData()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .fill(
                            colorScheme == .light
                                ? Const.lightBackground : Const.darkBackground,
                        ),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Const.radius)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1),
                )

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 粘贴目标模式（单选）
enum PasteTargetMode: Int, CaseIterable {
    case toApp = 0
    case toClipboard = 1

    var title: String {
        switch self {
        case .toApp: "到当前活动应用"
        case .toClipboard: "到剪贴板"
        }
    }

    var description: String {
        switch self {
        case .toApp: "将选定的项目直接粘贴到您当前正在使用的应用程序中。"
        case .toClipboard: "将选定的项目复制到系统剪贴板，以便随后手动粘贴。"
        }
    }
}

// MARK: - 粘贴目标模式行（单选）

struct PasteTargetModeRow: View {
    let mode: PasteTargetMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isSelected ? "record.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.system(size: 16))
                .onTapGesture {
                    onSelect()
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.title)
                    .font(.body)

                if !mode.description.isEmpty {
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - 纯文本粘贴行（独立开关）

struct PlainTextPasteRow: View {
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isEnabled ? .accentColor : .secondary)
                .font(.system(size: 16))
                .onTapGesture {
                    isEnabled.toggle()
                }

            Text("始终以纯文本粘贴")
                .font(.body)

            Spacer()
        }
        .padding(4)
        .contentShape(Rectangle())
        .onTapGesture {
            isEnabled.toggle()
        }
    }
}

// MARK: - 外观设置行

struct AppearanceSettingsRow: View {
    @State private var selectedAppearance: AppearanceMode = .init(
        rawValue: PasteUserDefaults.appearance,
    ) ?? .system

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
            Picker("", selection: $selectedAppearance) {
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
            .onChange(of: selectedAppearance) { _, newValue in
                PasteUserDefaults.appearance = newValue.rawValue
                applyAppearance(newValue)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            applyAppearance(selectedAppearance)
        }
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        DispatchQueue.main.async {
            let targetAppearance: NSAppearance?
            switch mode {
            case .system:
                targetAppearance = nil
            case .light:
                targetAppearance = NSAppearance(named: .aqua)
            case .dark:
                targetAppearance = NSAppearance(named: .darkAqua)
            }

            if NSApp.appearance != targetAppearance {
                NSApp.appearance = targetAppearance
            }
        }
    }
}

// MARK: - 历史时间滑块

struct HistoryTimeSlider: View {
    @Binding var selectedTimeUnit: HistoryTimeUnit
    @State private var sliderValue: Double = 0.0 // 范围 0-4，对应4个区间
    @State private var isEditing: Bool = false

    // 4个等长区间：
    // 区间0 (0.0-1.0): 1-6天 (6个细分)
    // 区间1 (1.0-2.0): 1-3周 (3个细分)
    // 区间2 (2.0-3.0): 1-11月 (11个细分)
    // 区间3 (3.0-4.0): 1年-永久 (2个细分)

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if !isEditing {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            ForEach(
                                Array(milestones.enumerated()),
                                id: \.offset,
                            ) { index, label in
                                Text(label)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 30)
                                    .offset(
                                        x: tickPosition(
                                            for: index,
                                            in: geometry.size.width,
                                        )
                                            - labelOffset(label: label),
                                    )
                            }
                        }
                    }
                    .transition(.opacity)
                }

                if isEditing {
                    Text(currentTimeUnit.displayText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
            }
            .frame(height: 16)
            .animation(.easeInOut(duration: 0.2), value: isEditing)

            ZStack {
                GeometryReader { geometry in
                    ForEach(0 ..< 5, id: \.self) { index in
                        let tickValue = tickSliderValue(for: index)
                        let isSelected =
                            !isEditing && abs(sliderValue - tickValue) < 0.01
                        if !isSelected {
                            Rectangle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 2.5, height: 3)
                                .offset(
                                    x: tickPosition(
                                        for: index,
                                        in: geometry.size.width,
                                    ),
                                    y: 3,
                                )
                        }
                    }
                }
                .frame(height: 24)
                .allowsHitTesting(false)

                Slider(
                    value: Binding(
                        get: { sliderValue },
                        set: { newValue in
                            sliderValue = snapToStep(newValue)
                        },
                    ),
                    in: 0 ... 4,
                    onEditingChanged: { editing in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditing = editing
                        }
                        if !editing {
                            saveCurrentValue()
                        }
                    },
                )
                .tint(.accentColor)
            }
        }
        .onAppear {
            sliderValue = internalValueToSliderValue(selectedTimeUnit.rawValue)
        }
    }

    private var milestones: [String] {
        ["天", "周", "月", "年", "永久"]
    }

    private var currentTimeUnit: HistoryTimeUnit {
        HistoryTimeUnit(rawValue: sliderValueToInternalValue(sliderValue))
    }

    private func labelOffset(label: String) -> CGFloat {
        if label == "天" {
            25.0
        } else if label == "永久" {
            25.0
        } else {
            15.0
        }
    }

    // 计算主刻度线位置（等分，但第一个刻度线对应2天的位置）
    private func tickPosition(for index: Int, in width: CGFloat) -> CGFloat {
        if index == 0 {
            let oneDaySliderValue = internalValueToSliderValue(2)
            return oneDaySliderValue * width / 4.0 + 8.5
        } else if index == 1 {
            return (CGFloat(1) * width / 4.0) + 3.5
        } else if index == 3 {
            return (CGFloat(3) * width / 4.0) - 5.0
        } else {
            return CGFloat(index) * width / 4.0
        }
    }

    // 获取刻度线对应的滑块值
    private func tickSliderValue(for index: Int) -> Double {
        if index == 0 {
            internalValueToSliderValue(1) // 1天
        } else {
            Double(index) // 1, 2, 3, 4 对应周、月、年、永久
        }
    }

    // 将内部值(1-22)转换为滑块值(0-4)
    private func internalValueToSliderValue(_ value: Int) -> Double {
        switch value {
        case 1 ... 6:
            // 天区间：1-6 映射到 0.0-1.0
            Double(value - 1) / 6.0
        case 7 ... 9:
            // 周区间：7-9 映射到 1.0-2.0
            1.0 + Double(value - 7) / 3.0
        case 10 ... 20:
            // 月区间：10-20 映射到 2.0-3.0
            2.0 + Double(value - 10) / 11.0
        case 21:
            // 年：21 映射到 3.0
            3.0
        case 22:
            // 永久：22 映射到 4.0
            4.0
        default:
            0.0
        }
    }

    // 将滑块值(0-4)转换为内部值(1-22)
    private func sliderValueToInternalValue(_ value: Double) -> Int {
        switch value {
        case 0 ..< 1.0:
            // 天区间：6个档位，对应 1-6
            let index = Int((value * 6.0).rounded())
            return max(1, min(6, index + 1))
        case 1.0 ..< 2.0:
            // 周区间：3个档位，对应 7-9
            let index = Int(((value - 1.0) * 3.0).rounded())
            return max(7, min(9, index + 7))
        case 2.0 ..< 3.0:
            // 月区间：11个档位，对应 10-20
            let index = Int(((value - 2.0) * 11.0).rounded())
            return max(10, min(20, index + 10))
        case 3.0 ..< 3.5:
            // 年
            return 21
        default:
            // 永久
            return 22
        }
    }

    // 根据所在区间应用不同的步长
    private func snapToStep(_ value: Double) -> Double {
        let step: Double
        switch value {
        case 0 ..< 1.0:
            // 天区间：6个步长
            step = 1.0 / 6.0
        case 1.0 ..< 2.0:
            // 周区间：3个步长
            step = 1.0 / 3.0
        case 2.0 ..< 3.0:
            // 月区间：11个步长
            step = 1.0 / 11.0
        case 3.0 ..< 4.0:
            // 年-永久区间：只有2个值，3.0是年，4.0是永久
            return value < 3.5 ? 3.0 : 4.0
        default:
            step = 1.0
        }

        let sectionStart = floor(value)
        let offsetInSection = value - sectionStart

        let snappedOffset = round(offsetInSection / step) * step
        return sectionStart + snappedOffset
    }

    private func saveCurrentValue() {
        let timeUnit = currentTimeUnit
        selectedTimeUnit = timeUnit
        PasteUserDefaults.historyTime = timeUnit.rawValue
    }
}

#Preview {
    GeneralSettingView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
