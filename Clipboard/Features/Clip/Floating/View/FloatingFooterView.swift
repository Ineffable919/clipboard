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

    var onBackgroundClick: (() -> Void)?

    func configure(topVM: TopBarViewModel) {
        self.topVM = topVM
        topVM.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updatePauseState() }
            .store(in: &cancellables)
        updateCount()
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

        countLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
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

        pauseTimeLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        pauseTimeLabel.textColor = .secondaryLabelColor

        pauseStack.orientation = .horizontal
        pauseStack.alignment = .centerY
        pauseStack.spacing = Const.space4
        pauseStack.edgeInsets = NSEdgeInsets(top: Const.space4, left: Const.space8, bottom: Const.space4, right: Const.space8)
        pauseStack.addArrangedSubview(pauseIcon)
        pauseStack.addArrangedSubview(pauseTimeLabel)
        pauseStack.wantsLayer = true
        pauseStack.layer?.cornerRadius = Const.btnRadius
        pauseStack.layer?.cornerCurve = .continuous
        pauseStack.isHidden = true

        pauseButton.isBordered = false
        pauseButton.title = ""
        pauseButton.target = self
        pauseButton.action = #selector(resumePasteboard)
        addSubview(pauseButton)
        addSubview(pauseStack)

        // 布局
        countLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        pauseStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Const.space12)
            make.centerY.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(Const.space6)
        }

        pauseButton.snp.makeConstraints { make in
            make.edges.equalTo(pauseStack)
        }

        Publishers.Merge(
            UserDefaults.standard.publisher(for: \.backgroundType).map { _ in () },
            UserDefaults.standard.publisher(for: \.glassMaterial).map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.handleBackgroundSettingsChange() }
        .store(in: &cancellables)
    }

    // MARK: - Background

    private static func buildEffectView() -> NSView {
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

    override func mouseDown(with _: NSEvent) {
        onBackgroundClick?()
    }

    @objc private func resumePasteboard() {
        topVM?.resume()
    }
}
