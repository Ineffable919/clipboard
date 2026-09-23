//
//  HistorySettingsSection.swift
//  Clipboard
//

import SwiftUI

struct HistorySettingsSection: View {
    @State private var isClearing = false
    @State private var selectedHistoryTimeUnit: HistoryTimeUnit =
        .init(rawValue: PasteUserDefaults.historyTime)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(.generalHistoryTitle)
                    .font(.headline)
                    .bold()
                Image(systemName: "exclamationmark.circle")
                    .help(Text(.generalHistoryCleanupHint))
            }

            VStack(alignment: .leading, spacing: Const.space8) {
                HistoryTimeSlider(
                    selectedTimeUnit: $selectedHistoryTimeUnit
                )
                .onChange(of: selectedHistoryTimeUnit) { _, newValue in
                    PasteUserDefaults.historyTime = newValue.rawValue
                }

                HStack {
                    Spacer()
                    if isClearing {
                        ProgressView().controlSize(.small)
                    }
                    SystemButton(
                        title: .generalClearHistory,
                        action: PasteDataStore.main.clearAllData
                    )
                    .disabled(isClearing)
                }
            }
            .padding(Const.space12)
            .settingsStyle()
        }
        .onReceive(PasteDataStore.main.clearingHistory) { isClearing = $0 }
    }
}
