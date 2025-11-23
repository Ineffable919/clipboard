//
//  EditableChipView.swift
//  Clipboard
//
//  Created by crown on 2025/9/13.
//

import SwiftUI

struct EditableChip: View {
    @Binding var name: String
    @Binding var color: Color
    var focus: FocusState<FocusField?>.Binding

    var onCommit: () -> Void
    var onCancel: () -> Void
    var onCycleColor: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .onTapGesture { onCycleColor() }

            TextField("", text: $name)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.disabled)
                .focused(focus, equals: .newChip)
                .onSubmit { onCommit() }
        }
        .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08)),
        )
        .cornerRadius(Const.radius)
    }
}
