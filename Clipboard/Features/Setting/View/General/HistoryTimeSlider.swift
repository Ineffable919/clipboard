//
//  HistoryTimeSlider.swift
//  Clipboard
//

import SwiftUI

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
                GeometryReader { geometry in
                    ForEach(0 ..< 5, id: \.self) { index in
                        let tickValue = tickSliderValue(for: index)
                        let isSelected =
                            !isEditing && abs(sliderValue - tickValue) < 0.01
                        if !isSelected {
                            Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 1.5, height: 2)
                                .offset(
                                    x: tickPosition(
                                        for: index,
                                        in: geometry.size.width
                                    ),
                                    y: geometry.size.height - 3
                                )
                        }
                    }
                }
                .allowsHitTesting(false)

                Slider(
                    value: $sliderValue.snappedHistoryValue,
                    in: 0 ... 4,
                    onEditingChanged: { editing in
                        isEditing = editing
                        if !editing {
                            selectedTimeUnit = currentTimeUnit
                        }
                    }
                )
                .accessibilityLabel(Text(.generalHistoryTitle))
                .accessibilityValue(Text(currentTimeUnit.displayText))
            }

            HStack {
                ForEach(0 ..< 5, id: \.self) { index in
                    Text(milestones[index])
                        .font(.callout)
                }
            }
            .hidden()
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity, minHeight: Const.space16)
            .overlay {
                ZStack {
                    if !isEditing {
                        GeometryReader { geometry in
                            let width = geometry.size.width
                            ZStack(alignment: .leading) {
                                ForEach(
                                    Array(milestones.enumerated()),
                                    id: \.offset
                                ) { index, label in
                                    let position = tickPosition(for: index, in: width)
                                    Text(label)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .alignmentGuide(.leading) { dimensions in
                                            let centered = position - dimensions.width / 2
                                            return -max(0, min(centered, width - dimensions.width))
                                        }
                                        .frame(
                                            width: width,
                                            alignment: .leading
                                        )
                                }
                            }
                        }
                    }

                    if isEditing {
                        Text(currentTimeUnit.displayText)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isEditing)
        }
        .onAppear {
            sliderValue = internalValueToSliderValue(selectedTimeUnit.rawValue)
        }
        .onChange(of: selectedTimeUnit) { _, newValue in
            if !isEditing {
                sliderValue = internalValueToSliderValue(newValue.rawValue)
            }
        }
    }

    private var milestones: [LocalizedStringResource] {
        [.historyRangeDay, .historyRangeWeek, .historyRangeMonth, .historyRangeYear, .historyRangeForever]
    }

    private var currentTimeUnit: HistoryTimeUnit {
        HistoryTimeUnit(rawValue: sliderValueToInternalValue(sliderValue))
    }

    /// 主刻度沿滑块行程等分，两端为滑块手柄预留空间。
    private func tickPosition(for index: Int, in width: CGFloat) -> CGFloat {
        let inset: CGFloat = 10
        return inset + max(0, width - inset * 2) * CGFloat(index) / 4
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

}

private extension Double {

    var snappedHistoryValue: Double {
        get { self }
        set { self = Self.snapToStep(newValue) }
    }

    static func snapToStep(_ value: Double) -> Double {
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

        let sectionStart = value.rounded(.down)
        let offsetInSection = value - sectionStart
        let snappedOffset = (offsetInSection / step).rounded() * step
        return sectionStart + snappedOffset
    }
}
