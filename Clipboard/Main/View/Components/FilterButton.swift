//
//  FilterButton.swift
//  Clipboard
//
//  Created by crown on 2025/12/15.
//

import SwiftUI

struct FilterButton: View {
    let icon: AnyView
    let label: String
    let isSelected: Bool
    let action: () -> Void

    init(
        @ViewBuilder icon: () -> some View,
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.icon = AnyView(icon())
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }

    init(
        systemImage: String,
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        icon = AnyView(
            Image(systemName: systemImage)
                .foregroundStyle(isSelected ? .white : .secondary)
        )
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Const.space8) {
                icon.frame(width: 20.0, height: 20.0)
                Text(label)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .padding(.horizontal, Const.space8)
            .padding(.vertical, Const.space4)
            .background(
                RoundedRectangle(cornerRadius: Const.radius, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.accentColor
                            : Color.secondary.opacity(0.15)
                    )
            )
            .frame(width: 140.0, height: 30.0)
        }
        .buttonStyle(.plain)
    }
}
