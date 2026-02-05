//
//  ChipComponents.swift
//  Clipboard
//
//  Created by crown on 2026/1/29.
//

import SwiftUI

// MARK: - 分类标签编辑器视图

struct ChipEditorView: View {
    @Binding var name: String
    @Binding var color: Color
    @FocusState.Binding var focus: FocusField?
    var focusValue: FocusField

    var onSubmit: () -> Void
    var onCycleColor: () -> Void

    @AppStorage(PrefKey.displayMode.rawValue) private var displayModeRaw: Int = 0

    private var displayMode: DisplayMode {
        .init(rawValue: displayModeRaw) ?? .drawer
    }

    private var circleSize: CGFloat {
        displayMode == .floating ? Const.space10 : Const.space12
    }

    private var fontSize: CGFloat {
        displayMode == .floating ? 11.0 : 13.0
    }

    private var editorPadding: EdgeInsets {
        if displayMode == .floating {
            .init(
                top: Const.space4,
                leading: Const.space8,
                bottom: Const.space4,
                trailing: Const.space8
            )
        } else {
            Const.chipPadding
        }
    }

    var body: some View {
        HStack(spacing: Const.space6) {
            Circle()
                .fill(color)
                .frame(width: circleSize, height: circleSize)
                .onTapGesture {
                    onCycleColor()
                }

            TextField("", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: fontSize))
                .focused($focus, equals: focusValue)
                .onSubmit {
                    onSubmit()
                }
        }
        .padding(editorPadding)
        .onAppear {
            Task { @MainActor in
                focus = focusValue
            }
        }
    }
}
