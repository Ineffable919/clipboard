//
//  GeneralSettingView.swift
//  Clipboard
//
//  Created by crown on 2025/10/28.
//

import SwiftUI

// MARK: - 通用设置视图

struct GeneralSettingView: View {
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                GeneralPreferencesCard()
                PasteItemsSettingsSection()
                HistorySettingsSection()

                Spacer(minLength: 20)
            }
            .padding([.horizontal, .bottom], Const.space24)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let viewModel = SettingViewModel()
    GeneralSettingView()
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
        .environment(viewModel)
}
