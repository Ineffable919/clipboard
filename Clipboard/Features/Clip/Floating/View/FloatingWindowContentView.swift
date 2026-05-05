//
//  FloatingWindowContentView.swift
//  Clipboard
//
//  浮动窗口主容器：背景 + Header + HistoryView + Footer 的布局
//

import AppKit
import Combine
import SnapKit

final class FloatingWindowContentView: NSView {
    // MARK: - Subviews

    private var effectView: NSView
    private let contentView = NSView()
    let headerView = FloatingHeaderView()
    let historyView = FloatingHistoryView()
    let footerView = FloatingFooterView()

    // MARK: - State

    let topVM = TopBarViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var lastBackgroundType: Int = PasteUserDefaults.backgroundType
    private var lastGlassMaterial: Int = PasteUserDefaults.glassMaterial

    // MARK: - Init

    override init(frame: NSRect) {
        effectView = Self.buildEffectView(frame: frame)
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Lifecycle

    // MARK: - Setup

    private func setup() {
        wantsLayer = true

        addSubview(effectView)

        let container: NSView
        if effectView is NSVisualEffectView {
            effectView.addSubview(contentView)
            contentView.snp.makeConstraints { $0.edges.equalToSuperview() }
            container = contentView
        } else {
            container = self
        }

        container.addSubview(historyView)
        container.addSubview(headerView)
        container.addSubview(footerView)

        headerView.configure(topVM: topVM)
        historyView.configure(topVM: topVM)
        footerView.configure(topVM: topVM)

        historyView.onActivateSearch = { [weak self] text in
            self?.headerView.activateSearch(with: text)
        }
        headerView.onSearchBecameFirstResponder = { [weak self] in
            self?.historyView.setFocusRegion(.search)
        }

        PasteDataStore.main.dataList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.footerView.updateCount()
            }
            .store(in: &cancellables)

        Publishers.Merge(
            UserDefaults.standard.publisher(for: \.backgroundType).map { _ in () },
            UserDefaults.standard.publisher(for: \.glassMaterial).map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in
            self?.handleBackgroundSettingsChange()
        }
        .store(in: &cancellables)

        headerView.searchField.$text
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self else { return }
                topVM.setQuery(text: text)
                topVM.handleQueryChange()
            }
            .store(in: &cancellables)

        topVM.filterDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.topVM.performSearch()
            }
            .store(in: &cancellables)

        layoutSubviews()
    }

    private func layoutSubviews() {
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let container: NSView = effectView is NSVisualEffectView ? contentView : self

        historyView.snp.makeConstraints { $0.edges.equalTo(container) }

        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(container)
        }

        footerView.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalTo(container)
            make.height.equalTo(FloatConst.footerHeight)
        }
    }

    // MARK: - Background

    private static func buildEffectView(frame: NSRect) -> NSView {
        if #available(macOS 26.0, *) {
            let bgType = BackgroundType(rawValue: PasteUserDefaults.backgroundType) ?? .liquid
            if bgType == .liquid {
                let glassView = NSGlassEffectView()
                glassView.frame = frame
                glassView.cornerRadius = Const.radius
                return glassView
            }
        }

        let visualEffect = NSVisualEffectView()
        visualEffect.wantsLayer = true
        visualEffect.frame = frame
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        let material = GlassMaterial(rawValue: PasteUserDefaults.glassMaterial) ?? .regular
        visualEffect.material = material.nsMaterial
        return visualEffect
    }

    private func handleBackgroundSettingsChange() {
        let currentBgType = PasteUserDefaults.backgroundType
        let currentMaterial = PasteUserDefaults.glassMaterial

        guard currentBgType != lastBackgroundType || currentMaterial != lastGlassMaterial else {
            return
        }

        let bgTypeChanged = currentBgType != lastBackgroundType
        lastBackgroundType = currentBgType
        lastGlassMaterial = currentMaterial

        if !bgTypeChanged, let ve = effectView as? NSVisualEffectView {
            let material = GlassMaterial(rawValue: currentMaterial) ?? .regular
            ve.material = material.nsMaterial
        } else {
            rebuildEffectView()
        }
    }

    private func rebuildEffectView() {
        historyView.removeFromSuperview()
        headerView.removeFromSuperview()
        footerView.removeFromSuperview()
        contentView.removeFromSuperview()
        effectView.removeFromSuperview()

        effectView = Self.buildEffectView(frame: bounds)
        addSubview(effectView)

        let container: NSView
        if effectView is NSVisualEffectView {
            effectView.addSubview(contentView)
            contentView.snp.makeConstraints { $0.edges.equalToSuperview() }
            container = contentView
        } else {
            container = self
        }

        container.addSubview(historyView)
        container.addSubview(headerView)
        container.addSubview(footerView)

        layoutSubviews()
        layoutSubtreeIfNeeded()
    }
}
