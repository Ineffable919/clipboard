//
//  AISettingsView.swift
//  Clipboard
//
//  Created by crown on 2026/6/2
//

import SwiftUI

// MARK: - AISettingsView

struct AISettingsView: View {
    @State private var isEnabled: Bool
    @State private var selectedClient: MCPClientInfo?
    private let server: MCPServer

    init(
        initialEnabled: Bool = MCPEnableFlag.isEnabled,
        server: MCPServer = .shared
    ) {
        self.server = server
        _isEnabled = State(initialValue: initialEnabled)
    }

    private var clients: [MCPClientInfo] {
        MCPClientInfo.all(endpoint: server.endpoint)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Const.space20) {
                Text(.mcpSectionTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.leading, Const.space10)
                    .padding(.bottom, -Const.space8)
                MCPHeaderCard(isEnabled: $isEnabled, server: server)
                if isEnabled {
                    HStack {
                        Spacer()
                        MCPClientMenu(
                            title: String(localized: .mcpConnectTools),
                            clients: clients
                        ) { client in
                            selectedClient = client
                        }
                        .fixedSize()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding([.horizontal, .bottom], Const.space20)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .sheet(item: $selectedClient) { client in
            MCPClientDetailSheet(client: client)
        }
    }
}

#Preview("Disabled") {
    AISettingsView(initialEnabled: false)
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}

#Preview("Port unavailable") {
    AISettingsView(
        initialEnabled: true,
        server: MCPServer(previewStatus: .failed)
    )
    .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}

#Preview("Enabled") {
    AISettingsView(initialEnabled: true)
        .frame(width: Const.settingWidth - 150, height: Const.settingHeight)
}
