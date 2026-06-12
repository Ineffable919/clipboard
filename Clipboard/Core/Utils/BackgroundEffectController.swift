//
//  BackgroundEffectController.swift
//  Clipboard
//
//  统一管理窗口的背景效果视图（NSGlassEffectView / NSVisualEffectView）
//  以及随用户偏好变化的切换/重建逻辑。
//

import AppKit
import Combine
import SnapKit

@MainActor
final class BackgroundEffectController {
    private(set) var effectView: NSView
    let contentContainer: NSView

    private weak var host: NSView?
    private let cornerRadius: CGFloat
    private let innerPadding: CGFloat

    private var lastBackgroundType: Int = PasteUserDefaults.backgroundType
    private var cancellables = Set<AnyCancellable>()

    init(cornerRadius: CGFloat, innerPadding: CGFloat = 0) {
        self.cornerRadius = cornerRadius
        self.innerPadding = innerPadding

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        if #available(macOS 26.0, *) {
            container.layer?.cornerRadius = cornerRadius
        }
        container.layer?.masksToBounds = true
        contentContainer = container

        effectView = Self.buildEffectView(
            cornerRadius: cornerRadius,
            contentContainer: container
        )

        observeSettings()
    }

    func install(in host: NSView) {
        self.host = host
        attach()
    }

    private func attach() {
        guard let host else { return }
        host.addSubview(effectView)
        effectView.snp.remakeConstraints { make in
            make.leading.equalTo(innerPadding)
            make.trailing.equalTo(-innerPadding)
            make.top.equalToSuperview()
            make.bottom.equalTo(-innerPadding)
        }
        if effectView is NSVisualEffectView {
            effectView.addSubview(contentContainer)
            contentContainer.snp.remakeConstraints { $0.edges.equalToSuperview() }
        }
    }

    private static func buildEffectView(
        cornerRadius: CGFloat,
        contentContainer: NSView
    ) -> NSView {
        if #available(macOS 26.0, *) {
            let bgType = BackgroundType(rawValue: PasteUserDefaults.backgroundType) ?? .liquid
            if bgType == .liquid {
                let glassView = NSGlassEffectView()
                glassView.cornerRadius = cornerRadius
                glassView.contentView = contentContainer
                return glassView
            }
        }

        let visualEffect = NSVisualEffectView()
        visualEffect.wantsLayer = true
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        if #available(macOS 26.0, *) {
            visualEffect.layer?.cornerRadius = cornerRadius
        }
        visualEffect.material = .popover
        return visualEffect
    }

    private func observeSettings() {
        UserDefaults.standard.publisher(for: \.backgroundType)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleSettingsChange() }
            .store(in: &cancellables)
    }

    private func handleSettingsChange() {
        let currentBgType = PasteUserDefaults.backgroundType
        guard currentBgType != lastBackgroundType else { return }
        lastBackgroundType = currentBgType
        rebuild()
    }

    private func rebuild() {
        guard let host else { return }
        contentContainer.removeFromSuperview()
        effectView.removeFromSuperview()

        effectView = Self.buildEffectView(
            cornerRadius: cornerRadius,
            contentContainer: contentContainer
        )
        attach()
        host.layoutSubtreeIfNeeded()
    }
}
