//
//  ChipEditingView.swift
//  Clipboard
//
//  Created by crown on 2025/12/14.
//

import SwiftUI

struct ChipEditorView<FocusValue: Hashable>: View {
    @Binding var name: String
    @Binding var color: Color
    var focus: FocusState<FocusValue?>.Binding
    var focusValue: FocusValue

    var onSubmit: () -> Void
    var onCycleColor: () -> Void

    var body: some View {
        HStack(spacing: Const.space8) {
            Circle()
                .fill(color)
                .frame(width: Const.space12, height: Const.space12)
                .onTapGesture {
                    onCycleColor()
                }

            TextField("", text: $name)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.disabled)
                .focused(focus, equals: focusValue)
                .onSubmit {
                    onSubmit()
                }
                .frame(minWidth: 48.0)
        }
        .padding(
            EdgeInsets(
                top: Const.space4,
                leading: Const.space10,
                bottom: Const.space4,
                trailing: Const.space10
            )
        )
        .background(
            RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .contentShape(Rectangle())
        .onAppear {
            DispatchQueue.main.async {
                focus.wrappedValue = focusValue
            }
        }
    }
}
