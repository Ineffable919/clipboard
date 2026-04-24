//
//  HistoryTimeSlider.swift
//  Clipboard
//

import SwiftUI

// MARK: - 自定义 Slider（macOS 26 以下使用）

@available(macOS, deprecated: 26)
struct ThinSlider: View {
    @Binding var value: Double
    let bounds: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                    .cornerRadius(2)

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(
                        width: geometry.size.width * normalizedValue,
                        height: 4
                    )
                    .cornerRadius(2)

                Capsule()
                    .fill(Color.white)
                    .frame(width: Const.space8, height: 20)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
                    .offset(x: geometry.size.width * normalizedValue - 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { dragValue in
                                if !isDragging {
                                    isDragging = true
                                    onEditingChanged(true)
                                }
                                let newNormalized = min(
                                    max(
                                        0,
                                        dragValue.location.x / geometry.size.width
                                    ),
                                    1
                                )
                                value =
                                    bounds.lowerBound
                                        + (bounds.upperBound - bounds.lowerBound)
                                        * newNormalized
                            }
                            .onEnded { _ in
                                isDragging = false
                                onEditingChanged(false)
                            }
                    )
            }
            .frame(height: Const.space24)
        }
        .frame(height: Const.space24)
    }

    private var normalizedValue: Double {
        (value - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
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
        VStack(spacing: Const.space8) {
            ZStack {
                if !isEditing {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            ForEach(
                                Array(milestones.enumerated()),
                                id: \.offset
                            ) { index, label in
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30)
                                    .offset(
                                        x: tickPosition(
                                            for: index,
                                            in: geometry.size.width
                                        )
                                            - labelOffset(for: index)
                                    )
                            }
                        }
                    }
                }

                if isEditing {
                    Text(currentTimeUnit.displayText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: Const.space16)
            .animation(.easeInOut(duration: 0.2), value: isEditing)

            ZStack {
                GeometryReader { geometry in
                    ForEach(0 ..< 5, id: \.self) { index in
                        let tickValue = tickSliderValue(for: index)
                        let isSelected =
                            !isEditing && abs(sliderValue - tickValue) < 0.01
                        if !isSelected {
                            Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 2.5, height: 3)
                                .offset(
                                    x: tickPosition(
                                        for: index,
                                        in: geometry.size.width
                                    ),
                                    y: 0.0
                                )
                        }
                    }
                }
                .allowsHitTesting(false)

                Slider(
                    value: Binding(
                        get: { sliderValue },
                        set: { newValue in
                            sliderValue = snapToStep(newValue)
                        }
                    ),
                    in: 0 ... 4,
                    onEditingChanged: { editing in
                        isEditing = editing
                        if !editing {
                            saveCurrentValue()
                        }
                    }
                )
            }
        }
        .onAppear {
            sliderValue = internalValueToSliderValue(selectedTimeUnit.rawValue)
        }
    }

    private var milestones: [LocalizedStringResource] {
        [.historyTimeSliderDay, .historyTimeSliderWeek, .historyTimeSliderMonth, .historyTimeSliderYear, .historyTimeSliderForever]
    }

    private var currentTimeUnit: HistoryTimeUnit {
        HistoryTimeUnit(rawValue: sliderValueToInternalValue(sliderValue))
    }

    private func labelOffset(for index: Int) -> CGFloat {
        if index == 0 || index == 4 {
            25.0
        } else {
            15.0
        }
    }

    /// 计算主刻度线位置（等分，但第一个刻度线对应2天的位置）
    private func tickPosition(for index: Int, in width: CGFloat) -> CGFloat {
        if index == 0 {
            let oneDaySliderValue = internalValueToSliderValue(2)
            return oneDaySliderValue * width / 4.0 + 8.5
        } else if index == 1 {
            return (CGFloat(1) * width / 4.0) + 3.5
        } else if index == 3 {
            return (CGFloat(3) * width / 4.0) - 5.0
        } else {
            return CGFloat(index) * width / 4.0 - 2.0
        }
    }

    /// 获取刻度线对应的滑块值
    private func tickSliderValue(for index: Int) -> Double {
        if index == 0 {
            internalValueToSliderValue(1) // 1天
        } else {
            Double(index) // 1, 2, 3, 4 对应周、月、年、永久
        }
    }

    /// 将内部值(1-22)转换为滑块值(0-4)
    private func internalValueToSliderValue(_ value: Int) -> Double {
        switch value {
        case 1 ... 6:
            Double(value - 1) / 6.0
        case 7 ... 9:
            1.0 + Double(value - 7) / 3.0
        case 10 ... 20:
            2.0 + Double(value - 10) / 11.0
        case 21:
            3.0
        case 22:
            4.0
        default:
            0.0
        }
    }

    /// 将滑块值(0-4)转换为内部值(1-22)
    private func sliderValueToInternalValue(_ value: Double) -> Int {
        switch value {
        case 0 ..< 1.0:
            let index = Int((value * 6.0).rounded())
            return max(1, min(6, index + 1))
        case 1.0 ..< 2.0:
            let index = Int(((value - 1.0) * 3.0).rounded())
            return max(7, min(9, index + 7))
        case 2.0 ..< 3.0:
            let index = Int(((value - 2.0) * 11.0).rounded())
            return max(10, min(20, index + 10))
        case 3.0 ..< 3.5:
            return 21
        default:
            return 22
        }
    }

    /// 根据所在区间应用不同的步长
    private func snapToStep(_ value: Double) -> Double {
        let step: Double
        switch value {
        case 0 ..< 1.0:
            step = 1.0 / 6.0
        case 1.0 ..< 2.0:
            step = 1.0 / 3.0
        case 2.0 ..< 3.0:
            step = 1.0 / 11.0
        case 3.0 ..< 4.0:
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
