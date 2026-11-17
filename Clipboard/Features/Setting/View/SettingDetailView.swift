//
//  SettingDetailView.swift
//  Clipboard
//
//  Created by crown on 2026/11/17
//

import SwiftUI

struct SettingDetailView: View {
    @Environment(SettingViewModel.self) private var viewModel

    private let titleHeight: CGFloat = 52

    var body: some View {
        let page = viewModel.selectedPage

        VStack(alignment: .leading, spacing: 0) {
            Text(page.title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .frame(height: titleHeight)
                .padding(.horizontal, Const.space20 + Const.space10)

            switch page {
            case .general:
                GeneralSettingView()
            case .appearance:
                AppearanceSettingsView()
            case .privacy:
                PrivacySettingView()
            case .keyboard:
                KeyboardSettingView()
            case .storage:
                StorageSettingView()
            case .mcp:
                AISettingsView()
            case .about:
                AboutSettingView()
            }
        }
    }
}
