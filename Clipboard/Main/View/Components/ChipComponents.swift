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

    var body: some View {
        HStack(spacing: Const.space6) {
            Circle()
                .fill(color)
                .frame(width: Const.space12, height: Const.space12)
                .onTapGesture {
                    onCycleColor()
                }

            TextField("", text: $name)
                .textFieldStyle(.plain)
                .focused($focus, equals: focusValue)
                .onSubmit {
                    onSubmit()
                }
        }
        .padding(Const.chipPadding)
        .overlay(
            RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                .stroke(
                    focus == focusValue
                        ? Color.accentColor.opacity(0.4)
                        : Color.clear,
                    lineWidth: 3
                )
        )
        .onAppear {
            Task { @MainActor in
                focus = focusValue
            }
        }
    }
}
