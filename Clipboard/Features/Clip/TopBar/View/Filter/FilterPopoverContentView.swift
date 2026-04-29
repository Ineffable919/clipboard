//
//  FilterPopoverContentView.swift
//  Clipboard
//
//  Popover 内容视图：组装类型、应用和日期三个筛选区域
//

import AppKit
import SnapKit

// MARK: - FlippedView

private final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

final class FilterPopoverContentView: NSView {
    // MARK: - Sections

    let typeSection = FilterTypeSectionView()
    let appSection = FilterAppSectionView()
    let groupSection = FilterGroupSectionView()
    let dateSection = FilterDateSectionView()

    // MARK: - Views

    private let scrollView = NSScrollView()
    private let contentView = FlippedView()
    private let mainStack = NSStackView()

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true

        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = contentView
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        addSubview(scrollView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.width.equalTo(scrollView)
        }

        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = Const.space16
        contentView.addSubview(mainStack)

        mainStack.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Const.space6)
            make.leading.trailing.bottom.equalToSuperview().inset(Const.space16)
        }

        typeSection.isHidden = true
        appSection.isHidden = true
        groupSection.isHidden = true

        mainStack.addArrangedSubview(typeSection)
        mainStack.addArrangedSubview(appSection)
        mainStack.addArrangedSubview(groupSection)
        mainStack.addArrangedSubview(dateSection)
    }
}
