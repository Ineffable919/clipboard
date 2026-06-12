//
//  SoundManager.swift
//  Clipboard
//
//  Created by crown on 2025/1/8.
//

import AppKit

enum SoundType: String {
    case copy
    case paste
}

final class SoundManager {
    static let shared = SoundManager()

    private var sounds: [SoundType: NSSound] = [:]

    private init() {
        loadSounds()
    }

    private func loadSounds() {
        for type in [SoundType.copy, SoundType.paste] {
            guard
                let soundURL = Bundle.main.url(
                    forResource: type.rawValue,
                    withExtension: "aiff"
                )
            else {
                log.warn("无法找到音效文件: \(type.rawValue).aiff")
                continue
            }

            guard let sound = NSSound(contentsOf: soundURL, byReference: false)
            else {
                log.warn("无法加载音效文件: \(soundURL.path)")
                continue
            }

            sounds[type] = sound
        }
    }

    func play(_ type: SoundType) {
        guard PasteUserDefaults.soundEnabled else { return }

        guard let sound = sounds[type], !sound.isPlaying else { return }
        sound.play()
    }
}
