//
//  HistorySettingsSection.swift
//  Clipboard
//

import SwiftUI

struct HistorySettingsSection: View {
    private enum Alert {
        case clearHistory
        case historyLimit(HistoryTimeUnit)
        case result(String)

        var title: String {
            switch self {
            case .clearHistory: String(localized: .clearDataMessage)
            case .historyLimit: String(localized: .generalHistoryLimitConfirmTitle)
            case let .result(message): message
            }
        }
    }

    @State private var alert: Alert?
    @State private var showAlert = false
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
                    SystemButton(title: .generalClearHistory) {
                        present(.clearHistory)
                    }
                    .disabled(isClearing || isUpdating)
                }
            }
            .padding(Const.space12)
            .settingsStyle()
        }
        .onReceive(PasteDataStore.main.clearingHistory) { isClearing = $0 }
        .alert(alert?.title ?? "", isPresented: $showAlert, presenting: alert) { alert in
            switch alert {
            case .clearHistory:
                Button(.delete, role: .destructive) {
                    clearHistory()
                }
                Button(.commonCancel, role: .cancel) {}
            case let .historyLimit(timeUnit):
                Button(.delete, role: .destructive) {
                    applyConfirmedLimit(timeUnit)
                }
                Button(.commonCancel, role: .cancel) {
                    restoreLimit()
                }
            case .result:
                Button(.commonConfirm, role: .cancel) {}
            }
        } message: { alert in
            if case .historyLimit = alert {
                Text(.generalHistoryLimitConfirmMessage)
            }
        }
    }

    private func present(_ alert: Alert) {
        self.alert = alert
        showAlert = true
    }

    private func restoreLimit() {
        selectedHistoryTimeUnit = .init(rawValue: PasteUserDefaults.historyTime)
        isUpdating = false
    }

    private func applyLimit(_ timeUnit: HistoryTimeUnit) {
        guard timeUnit.rawValue != PasteUserDefaults.historyTime else { return }
        isUpdating = true
        Task {
            do {
                if try await PasteDataStore.main.hasExpiredHistory(timeUnit) {
                    present(.historyLimit(timeUnit))
                } else {
                    PasteUserDefaults.historyTime = timeUnit.rawValue
                    isUpdating = false
                }
            } catch {
                historyLimitFailed(error)
            }
        }
    }

    private func applyConfirmedLimit(_ timeUnit: HistoryTimeUnit) {
        Task {
            do {
                try await PasteDataStore.main.applyHistoryLimit(timeUnit)
                PasteUserDefaults.historyTime = timeUnit.rawValue
                isUpdating = false
            } catch {
                historyLimitFailed(error)
            }
        }
    }

    private func historyLimitFailed(_ error: Error) {
        log.error("应用历史保留期限失败：\(error)")
        restoreLimit()
        present(.result(String(localized: .generalHistoryLimitFailed)))
    }

    private func clearHistory() {
        Task {
            do {
                let reclaimed = try await PasteDataStore.main.clearAllData()
                present(.result(String(localized: reclaimed ? .clearHistorySuccess : .clearHistorySpaceFailed)))
            } catch {
                log.error("清空历史失败：\(error)")
                present(.result(String(localized: .clearHistoryFailed)))
            }
        }
    }
}
