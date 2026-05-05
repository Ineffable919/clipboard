//
//  FloatingFooterView.swift
//  Clipboard
//
//  浮动窗口底部：条目数量 + 暂停指示器
//

import AppKit
import Combine
import SnapKit

final class FloatingFooterView: NSView {
    // MARK: - Subviews

    private let countLabel = NSTextField(labelWithString: "")
    private let pauseButton = NSButton()
    private let pauseTimeLabel = NSTextField(labelWithString: "")
    private let pauseStack = NSStackView()

    // MARK: - State

    private var effectView: NSView = FloatingFooterView.buildEffectView()
    private var lastBackgroundType: Int = PasteUserDefaults.backgroundType
    private var lastGlassMaterial: Int = PasteUserDefaults.glassMaterial
    private weak var topVM: TopBarViewModel?
    private var cancellables = Set<AnyCancellable>()
    private var displayTimer: Timer?

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // Timer 在 stopDisplayTimer 中 invalidate，deinit 时 Timer 会自动失效

    // MARK: - Public API

    func configure(topVM: TopBarViewModel) {
        self.topVM = topVM
        observePauseState()
        updateCount()
        updatePauseState()
    }

    func updateCount() {
        let count = PasteDataStore.main.filteredCount
        countLabel.stringValue = String(localized: .itemCount(count))
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true

        addSubview(effectView)
        effectView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalToSuperview().offset(-Const.windowRadis)
        }

        countLabel.font = .systemFont(ofSize: 12, weight: .regular)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .center
        addSubview(countLabel)

        // 暂停指示器
        let pauseIcon = NSImageView()
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        pauseIcon.image = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig)
        pauseIcon.contentTintColor = .controlAccentColor
        pauseIcon.snp.makeConstraints { make in
            make.width.height.equalTo(14)
        }

        pauseTimeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        pauseTimeLabel.textColor = .secondaryLabelColor

        pauseStack.orientation = .horizontal
        pauseStack.alignment = .centerY
        pauseStack.spacing = Const.space4
        pauseStack.addArrangedSubview(pauseIcon)
        pauseStack.addArrangedSubview(pauseTimeLabel)
        pauseStack.wantsLayer = true
        pauseStack.layer?.cornerRadius = 10
        pauseStack.layer?.cornerCurve = .continuous
        pauseStack.isHidden = true

        // 包装成可点击的按钮区域
        pauseButton.isBordered = false
        pauseButton.title = ""
        pauseButton.target = self
        pauseButton.action = #selector(resumePasteboard)
        pauseButton.addSubview(pauseStack)
        addSubview(pauseButton)

        pauseStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(NSEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        }

        // 布局
        countLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        pauseButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Const.space12)
            make.centerY.equalToSuperview()
        }

        Publishers.Merge(
            UserDefaults.standard.publisher(for: \.backgroundType).map { _ in () },
            UserDefaults.standard.publisher(for: \.glassMaterial).map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.handleBackgroundSettingsChange() }
        .store(in: &cancellables)
    }

    private func observePauseState() {
        NotificationCenter.default.publisher(for: .pasteboardPauseStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePauseState()
            }
            .store(in: &cancellables)
    }

    // MARK: - Background

    private static func buildEffectView() -> NSView {
        // Only bottom two corners rounded to match the window edge; inner-top corners stay square.
        let bottomCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        if #available(macOS 26.0, *) {
            let bgType = BackgroundType(rawValue: PasteUserDefaults.backgroundType) ?? .liquid
            if bgType == .liquid {
                let v = NSGlassEffectView()
                v.cornerRadius = Const.windowRadis
                v.wantsLayer = true
                v.layer?.maskedCorners = bottomCorners
                return v
            }
        }
        let ve = NSVisualEffectView()
        ve.wantsLayer = true
        ve.state = .active
        ve.blendingMode = .behindWindow
        ve.material = (GlassMaterial(rawValue: PasteUserDefaults.glassMaterial) ?? .regular).nsMaterial
        ve.layer?.cornerRadius = Const.windowRadis
        ve.layer?.maskedCorners = bottomCorners
        ve.layer?.masksToBounds = true
        return ve
    }

    private func handleBackgroundSettingsChange() {
        let currentBgType = PasteUserDefaults.backgroundType
        let currentMaterial = PasteUserDefaults.glassMaterial
        guard currentBgType != lastBackgroundType || currentMaterial != lastGlassMaterial else { return }
        let bgTypeChanged = currentBgType != lastBackgroundType
        lastBackgroundType = currentBgType
        lastGlassMaterial = currentMaterial
        if !bgTypeChanged, let ve = effectView as? NSVisualEffectView {
            ve.material = (GlassMaterial(rawValue: currentMaterial) ?? .regular).nsMaterial
        } else {
            rebuildEffectView()
        }
    }

    private func rebuildEffectView() {
        effectView.removeFromSuperview()
        effectView = Self.buildEffectView()
        addSubview(effectView, positioned: .below, relativeTo: countLabel)
        effectView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalToSuperview().offset(-Const.windowRadis)
        }
        layoutSubtreeIfNeeded()
    }

    private func updatePauseState() {
        guard let topVM else { return }
        let isPaused = topVM.isPaused

        pauseStack.isHidden = !isPaused

        if isPaused {
            pauseTimeLabel.stringValue = topVM.formattedRemainingTime
            startDisplayTimer()
        } else {
            stopDisplayTimer()
        }

        updatePauseBackground()
    }

    private func updatePauseBackground() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            pauseStack.layer?.backgroundColor = NSColor.controlAccentColor
                .withAlphaComponent(0.1).cgColor
        }
    }

    private func startDisplayTimer() {
        guard displayTimer == nil else { return }
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pauseTimeLabel.stringValue = self?.topVM?.formattedRemainingTime ?? ""
            }
        }
        RunLoop.main.add(displayTimer!, forMode: .common)
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updatePauseBackground()
    }

    @objc private func resumePasteboard() {
        topVM?.resume()
    }
}
