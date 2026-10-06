//
//  HistorySettingsSection.swift
//  Clipboard
//

import SwiftUI

struct HistorySettingsSection: View {
    @State private var isClearing = false
    @State private var isUpdating = false
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
                    applyLimit(newValue)
                }
                .disabled(isClearing || isUpdating)
                .padding(.top, Const.space8)

                Divider()
                    .padding(.vertical, Const.space4)

                HStack {
                    Spacer()
                    if isClearing {
                        ProgressView().controlSize(.small)
                    }
                    SystemButton(
                        title: .generalClearHistory,
                        action: PasteDataStore.main.clearAllData
                    )
                    .disabled(isClearing || isUpdating)
                }
            }
            .padding(Const.space12)
            .settingsStyle()
        }
        .onReceive(PasteDataStore.main.clearingHistory) { isClearing = $0 }
    }

    private func applyLimit(_ timeUnit: HistoryTimeUnit) {
        guard timeUnit.rawValue != PasteUserDefaults.historyTime else { return }
        isUpdating = true
        Task {
            defer { isUpdating = false }
            if await PasteDataStore.main.confirmHistoryLimit(timeUnit) {
                PasteUserDefaults.historyTime = timeUnit.rawValue
            } else {
                selectedHistoryTimeUnit = .init(rawValue: PasteUserDefaults.historyTime)
            }
        }
    }
}
