//
//  TimeManager.swift
//  Clipboard
//
//  Created by crown on 2025/10/6.
//

import Foundation

@MainActor
@Observable
final class TimeManager {
    var currentTime = Date()
    private var timer: Timer?

    static let shared = TimeManager()

    private init() {
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                self.currentTime = Date()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}
