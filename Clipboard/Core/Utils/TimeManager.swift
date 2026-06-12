//
//  TimeManager.swift
//  Clipboard
//
//  Created by crown on 2025/10/6.
//

import Combine
import Foundation

final class TimeManager {
    var currentTime = Date()
    private var timer: Timer?

    let tick = PassthroughSubject<Date, Never>()

    static let shared = TimeManager()

    private init() {
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                self.currentTime = Date()
                self.tick.send(self.currentTime)
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}
