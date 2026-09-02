//
//  PasteItemsSettingsSection.swift
//  Clipboard
//

import SwiftUI

struct PasteItemsSettingsSection: View {
    @Environment(SettingViewModel.self) private var viewModel

    @AppStorage(PrefKey.pasteDirect.rawValue)
    private var pasteDirect = true

    @AppStorage(PrefKey.pasteOnlyText.rawValue)
    private var pasteAsPlainText = false

    @AppStorage(PrefKey.removeTailingNewline.rawValue)
    private var removeTailingNewline = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(.generalPasteItemsTitle)
                .font(.headline)
                .bold()

            VStack(alignment: .leading, spacing: Const.space12) {
                HStack(alignment: .top, spacing: Const.space8) {
                    VStack(alignment: .leading, spacing: Const.space4) {
                        ForEach(PasteTargetMode.allCases, id: \.rawValue) { mode in
                            VStack(alignment: .leading, spacing: Const.space4) {
                                PasteTargetModeRow(
                                    mode: mode,
                                    isSelected: selectedPasteTarget == mode,
                                    onSelect: {
                                        pasteDirect = (mode == .toApp)
                                    }
                                )

                                if mode == .toApp,
                                   selectedPasteTarget == .toApp,
                                   !viewModel.hasAccessibilityPermission {
                                    AccessibilityButton(
                                        action: viewModel.openAccessibilitySettings
                                    )
                                    .padding(.leading, Const.space32)
                                }
                            }
                        }
                    }

                    PasteTargetIllustration(mode: selectedPasteTarget)
                        .frame(width: 144, height: 96)
                }

                Divider()

                ToggleRow(
                    isEnabled: $pasteAsPlainText,
                    title: .generalPastePlain
                )
                ToggleRow(
                    isEnabled: $removeTailingNewline,
                    title: .generalRemoveTailingNewline
                )
            }
            .padding(Const.space8)
            .settingsStyle()
        }
    }

    private var selectedPasteTarget: PasteTargetMode {
        pasteDirect ? .toApp : .toClipboard
    }
}
