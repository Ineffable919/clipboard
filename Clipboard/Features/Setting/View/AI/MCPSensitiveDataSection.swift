//
//  MCPSensitiveDataSection.swift
//  Clipboard
//
//  Created by crown on 2026/11/17
//

import SwiftUI

/// MCP 敏感信息选项：搜索结果中遮挡疑似密钥
struct MCPSensitiveDataSection: View {
    @AppStorage(PrefKey.mcpMaskSecrets.rawValue)
    private var maskSecrets = true

    var body: some View {
        VStack(alignment: .leading, spacing: Const.space12) {
            Text(.mcpSensitiveData)
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.leading, Const.space10)

            PrivacyToggleRow(
                title: String(localized: .mcpMaskSecrets),
                subtitle: String(localized: .mcpMaskSecretsDesc),
                isOn: $maskSecrets
            )
            .padding(.horizontal, Const.space10)
            .settingsStyle()
        }
    }
}

#Preview {
    MCPSensitiveDataSection()
        .padding()
        .frame(width: 480)
}
