//
//  ChipEditingView.swift
//  Clipboard
//
//  Created by crown on 2025/12/14.
//

import SwiftUI

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
                .font(.body)
                .focused($focus, equals: focusValue)
                .onSubmit {
                    onSubmit()
                }
        }
        .padding(
            EdgeInsets(
                top: Const.space6,
                leading: Const.space10,
                bottom: Const.space6,
                trailing: Const.space10
            )
        )
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
