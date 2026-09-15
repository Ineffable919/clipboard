//
//  ExpirationSlider.swift
//  Clipboard
//
//  Created by crown on 2026/9/15.
//

import SwiftUI

// MARK: - Expiration

enum Expiration: Equatable {
    case days(Int)
    case weeks(Int)
    case months(Int)
    case years(Int)
    case forever

    var displayText: String {
        switch self {
        case .days(let value):
            return "\(value)天"

        case .weeks(let value):
            return "\(value)周"

        case .months(let value):
            return "\(value)个月"

        case .years(let value):
            return "\(value)年"

        case .forever:
            return "永久"
        }
    }
}

// MARK: - Slider Point

private struct ExpirationSliderPoint: Identifiable {
    let position: Double
    let value: Expiration

    var id: Double {
        position
    }

    /// 天 / 周 / 月 / 年 / 永久
    var isMajor: Bool {
        abs(position - position.rounded()) < 0.0001
    }
}

// MARK: - Expiration Slider

struct ExpirationSlider: View {

    @Binding var selection: Expiration

    @State private var position: Double = 0
    @State private var isDragging = false

    private let labels = [
        "天",
        "周",
        "月",
        "年",
        "永久",
    ]

    /// 系统 Slider thumb 左右大概会留出这部分空间。
    /// 用它让顶部文字、刻度和 Slider 轨道尽量保持一致。
    private let sliderHorizontalInset: CGFloat = 14

    // MARK: Points

    private var points: [ExpirationSliderPoint] {
        var result: [ExpirationSliderPoint] = []

        // 0 -> 1
        // 1 天 -> 1 周
        //
        // 1天
        // 2天
        // 3天
        // 4天
        // 5天
        // 6天
        // 1周
        result += makePoints(
            segment: 0,
            values: [
                .days(1),
                .days(2),
                .days(3),
                .days(4),
                .days(5),
                .days(6),
                .weeks(1),
            ]
        )

        // 1 -> 2
        // 1 周 -> 1 个月
        //
        // 1周
        // 2周
        // 3周
        // 1个月
        result += makePoints(
            segment: 1,
            values: [
                .weeks(1),
                .weeks(2),
                .weeks(3),
                .months(1),
            ]
        )

        // 2 -> 3
        // 1 个月 -> 1 年
        //
        // 1个月
        // 2个月
        // ...
        // 11个月
        // 1年
        result += makePoints(
            segment: 2,
            values: (1...11).map { .months($0) }
                + [.years(1)]
        )

        // 3 -> 4
        // 1 年 -> 永久
        //
        // 只有一步
        result += makePoints(
            segment: 3,
            values: [
                .years(1),
                .forever,
            ]
        )

        return removeDuplicatePositions(result)
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 6) {

            // MARK: 顶部文字

            ZStack {
                if isDragging {
                    Text(selection.displayText)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                        .transition(.opacity)
                } else {
                    labelsView
                        .transition(.opacity)
                }
            }
            .frame(height: 24)

            VStack(spacing: 0) {
                
                // MARK: 刻度

                ticksView
                    .frame(height: 6)

                // MARK: Slider

                Slider(
                    value: Binding(
                        get: {
                            position
                        },
                        set: { newValue in
                            snap(to: newValue)
                        }
                    ),
                    in: 0...4,
                    onEditingChanged: { editing in
                        isDragging = editing
                    }
                )
            }
            
        }
        .padding(.horizontal, 20)
        .onAppear {
            syncPositionWithSelection()
        }
        .onChange(of: selection) { _, _ in
            guard !isDragging else {
                return
            }

            syncPositionWithSelection()
        }
        .animation(
            .easeInOut(duration: 0.12),
            value: isDragging
        )
    }

    // MARK: - Labels

    private var labelsView: some View {
        GeometryReader { proxy in

            let width =
                max(
                    0,
                    proxy.size.width
                        - sliderHorizontalInset * 2
                )

            ZStack {
                ForEach(
                    Array(labels.enumerated()),
                    id: \.offset
                ) { index, label in

                    let progress =
                        CGFloat(index)
                        / CGFloat(labels.count - 1)

                    let x =
                        sliderHorizontalInset
                        + width * progress

                    Text(label)
                        .foregroundStyle(.secondary)
                        .position(
                            x: x,
                            y: proxy.size.height / 2
                        )
                }
            }
        }
    }

    // MARK: - Ticks

    private var ticksView: some View {
        GeometryReader { proxy in

            let usableWidth =
                max(
                    0,
                    proxy.size.width
                        - sliderHorizontalInset * 2
                )

            ZStack(alignment: .topLeading) {
                ForEach(points) { point in

                    let progress =
                        CGFloat(point.position / 4)

                    let x =
                        sliderHorizontalInset
                        + usableWidth * progress

                    Capsule()
                        .fill(
                            point.isMajor
                                ? Color.secondary
                                : Color.clear
                        )
                        .frame(
                            width: point.isMajor ? 2 : 1,
                            height: point.isMajor ? 5 : 2
                        )
                        .position(
                            x: x,
                            y: point.isMajor ? 5.5 : 2.5
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Snap

    private func snap(to rawPosition: Double) {
        guard
            let nearest = points.min(by: {
                abs($0.position - rawPosition)
                    < abs($1.position - rawPosition)
            })
        else {
            return
        }

        position = nearest.position
        selection = nearest.value
    }

    // MARK: - Build Points

    private func makePoints(
        segment: Int,
        values: [Expiration]
    ) -> [ExpirationSliderPoint] {

        guard !values.isEmpty else {
            return []
        }

        guard values.count > 1 else {
            return [
                ExpirationSliderPoint(
                    position: Double(segment),
                    value: values[0]
                )
            ]
        }

        let intervalCount = values.count - 1

        return values.enumerated().map { index, value in

            let progress =
                Double(index)
                / Double(intervalCount)

            return ExpirationSliderPoint(
                position:
                    Double(segment)
                    + progress,
                value: value
            )
        }
    }

    // MARK: - Remove Duplicate Boundary Points

    private func removeDuplicatePositions(
        _ input: [ExpirationSliderPoint]
    ) -> [ExpirationSliderPoint] {

        var result: [ExpirationSliderPoint] = []

        for point in input {

            let exists = result.contains {
                abs($0.position - point.position) < 0.0001
            }

            if !exists {
                result.append(point)
            }
        }

        return result
    }

    // MARK: - Sync External Selection

    private func syncPositionWithSelection() {
        guard
            let point = points.first(where: {
                $0.value == selection
            })
        else {
            return
        }

        position = point.position
    }
}

// MARK: - Example

struct ContentView: View {

    @State private var expiration: Expiration = .days(1)

    var body: some View {
        VStack {
            ExpirationSlider(
                selection: $expiration
            )
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
