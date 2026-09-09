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
    private let modeButton = NSButton()

    // MARK: - State

    private let effectView: NSView = FloatingFooterView.buildEffectView()
    private weak var topVM: TopBarViewModel?
    private var cancellables = Set<AnyCancellable>()
    private var timerCancellable: AnyCancellable?

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Public API

    var onBackgroundClick: (() -> Void)?
    var onDisplayModeChanged: ((FloatingDisplayMode) -> Void)?
    var displayMode: FloatingDisplayMode = .standard {
        didSet {
            updateModeIcon()
            countLabel.font = .systemFont(
                ofSize: displayMode == .standard ? NSFont.systemFontSize : 11, weight: .regular
            )
        }
    }

    @objc private func showDisplayModes() {
        let menu = NSMenu()
        for mode in FloatingDisplayMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
            item.target = self
            item.tag = mode.rawValue
            item.state = mode == displayMode ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: modeButton.bounds.maxY), in: modeButton)
    }

    @objc private func selectDisplayMode(_ item: NSMenuItem) {
        guard let mode = FloatingDisplayMode(rawValue: item.tag) else { return }
        onDisplayModeChanged?(mode)
    }

    func configure(topVM: TopBarViewModel) {
        self.topVM = topVM
        PasteBoard.main.$isPaused
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

        setupModeButton()

        // 暂停指示器
        let pauseIcon = NSImageView()
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        pauseIcon.image = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig)
        pauseIcon.contentTintColor = .controlAccentColor
        pauseIcon.imageScaling = .scaleNone
        pauseIcon.snp.makeConstraints { make in
            make.width.height.equalTo(14)
        }

        pauseTimeLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        pauseTimeLabel.textColor = .secondaryLabelColor

        pauseStack.orientation = .horizontal
        pauseStack.alignment = .centerY
        pauseStack.spacing = Const.space4
        pauseStack.edgeInsets = NSEdgeInsets(
            top: Const.space2, left: Const.space6, bottom: Const.space2, right: Const.space6
        )
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
        layoutCountLabel(isPaused: false)

        pauseStack.snp.makeConstraints { make in
            make.leading.equalTo(modeButton.snp.trailing).offset(Const.space4)
            make.centerY.equalToSuperview()
            make.height.equalTo(20)
        }

        pauseButton.snp.makeConstraints { make in
            make.edges.equalTo(pauseStack)
        }
    }

    private func setupModeButton() {
        modeButton.isBordered = false
        modeButton.title = ""
        updateModeIcon()
        modeButton.imageScaling = .scaleNone
        modeButton.contentTintColor = .secondaryLabelColor
        modeButton.toolTip = String(localized: .floatingDisplayMode)
        modeButton.setAccessibilityLabel(String(localized: .floatingDisplayMode))
        modeButton.target = self
        modeButton.action = #selector(showDisplayModes)
        addSubview(modeButton)
        modeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Const.space8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }
    }

    private func updateModeIcon() {
        modeButton.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(
                pointSize: displayMode == .standard ? 15 : 12, weight: .regular
            ))
    }

    // MARK: - Background

    private func layoutCountLabel(isPaused: Bool) {
        countLabel.snp.remakeConstraints { make in
            make.centerY.equalToSuperview()
            make.centerX.equalToSuperview().priority(750)
            make.leading.greaterThanOrEqualTo(isPaused ? pauseStack.snp.trailing : modeButton.snp.trailing)
                .offset(Const.space8)
            make.trailing.lessThanOrEqualToSuperview().inset(Const.space12)
        }
    }

    private static func buildEffectView() -> NSView {
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.cornerRadius = 0
            return glassView
        }
        let ve = NSVisualEffectView()
        ve.wantsLayer = true
        ve.state = .active
        ve.blendingMode = .withinWindow
        ve.material = .popover
        return ve
    }

    private func updatePauseState() {
        guard let topVM else { return }
        let isPaused = PasteBoard.main.isPaused

        pauseStack.isHidden = !isPaused
        pauseButton.isHidden = !isPaused
        layoutCountLabel(isPaused: isPaused)

        if isPaused {
            pauseTimeLabel.stringValue = topVM.formattedRemainingTime
            timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.pauseTimeLabel.stringValue = self?.topVM?.formattedRemainingTime ?? ""
                }
        } else {
            timerCancellable = nil
        }

        updatePauseBackground()
    }

    private func updatePauseBackground() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            pauseStack.layer?.backgroundColor = NSColor.controlAccentColor
                .withAlphaComponent(0.1).cgColor
        }
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
