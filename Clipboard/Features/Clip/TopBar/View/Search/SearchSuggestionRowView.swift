//
//  SearchSuggestionRowView.swift
//  Clipboard
//
//  联想列表单行视图：icon + 高亮匹配文字
//

import AppKit
import SnapKit

// MARK: - Cell View

final class SearchSuggestionCellView: NSView {
    // MARK: - Metrics

    private enum Metrics {
        static let iconSize: CGFloat = 18
        static let horizontalPadding: CGFloat = 8
        static let iconTextGap: CGFloat = 6
        static let fontSize: CGFloat = 12
    }

    // MARK: - Subviews

    private let iconView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        return iv
    }()

    private let labelField: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.lineBreakMode = .byTruncatingTail
        tf.maximumNumberOfLines = 1
        tf.cell?.truncatesLastVisibleLine = true
        return tf
    }()

    // MARK: - State

    private(set) var isHighlighted = false
    private var currentTitle: String = ""
    private var currentQuery: String = ""

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    // MARK: - Setup

    private func setup() {
        addSubview(iconView)
        addSubview(labelField)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Metrics.horizontalPadding)
            make.centerY.equalToSuperview()
            make.size.equalTo(Metrics.iconSize)
        }

        labelField.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Metrics.iconTextGap)
            make.trailing.lessThanOrEqualToSuperview().offset(-Metrics.horizontalPadding)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Configure

    static func preferredWidth(for title: String, query: String) -> CGFloat {
        let attributedTitle = attributedTitle(title, query: query, isHighlighted: false)
        return ceil(
            Metrics.horizontalPadding
                + Metrics.iconSize
                + Metrics.iconTextGap
                + attributedTitle.size().width
                + Metrics.horizontalPadding
        )
    }

    func configure(item: SearchSuggestionItem, query: String) {
        iconView.image = item.icon
        currentTitle = item.title
        currentQuery = query
        updateLabelAppearance()
    }

    func setHighlighted(_ highlighted: Bool) {
        guard isHighlighted != highlighted else { return }
        isHighlighted = highlighted
        updateLabelAppearance()
    }

    // MARK: - Appearance

    private func updateLabelAppearance() {
        labelField.attributedStringValue = highlightedTitle(
            currentTitle,
            query: currentQuery
        )
        if isHighlighted {
            iconView.contentTintColor = .white
        } else {
            iconView.contentTintColor = nil
        }
    }

    // MARK: - Highlight Text

    private func highlightedTitle(_ title: String, query: String) -> NSAttributedString {
        Self.attributedTitle(title, query: query, isHighlighted: isHighlighted)
    }

    private static func fuzzyMatchRanges(_ title: String, query: String) -> [Range<String.Index>] {
        let queryLower = query.lowercased()
        let titleLower = title.lowercased()
        var queryIndex = queryLower.startIndex
        var titleIndex = titleLower.startIndex
        var ranges: [Range<String.Index>] = []

        while queryIndex < queryLower.endIndex, titleIndex < titleLower.endIndex {
            if titleLower[titleIndex] == queryLower[queryIndex] {
                let end = title.index(after: titleIndex)
                ranges.append(titleIndex ..< end)
                titleIndex = end
                queryIndex = queryLower.index(after: queryIndex)
            } else {
                titleIndex = titleLower.index(after: titleIndex)
            }
        }

        return ranges
    }

    private static func attributedTitle(
        _ title: String,
        query: String,
        isHighlighted: Bool
    ) -> NSAttributedString {
        let baseFont = NSFont.systemFont(ofSize: Metrics.fontSize)
        let boldFont = NSFont.boldSystemFont(ofSize: Metrics.fontSize)

        let textColor: NSColor = isHighlighted ? .white : .labelColor

        let attributed = NSMutableAttributedString(
            string: title,
            attributes: [
                .font: baseFont,
                .foregroundColor: textColor,
            ]
        )

        guard !query.isEmpty else { return attributed }

        let matchRanges = fuzzyMatchRanges(title, query: query)
        for range in matchRanges {
            let nsRange = NSRange(range, in: title)
            attributed.addAttribute(.font, value: boldFont, range: nsRange)
        }

        return attributed
    }
}

// MARK: - Row View (背景绘制)

final class SearchSuggestionRowView: NSTableRowView {
    private(set) var isItemHighlighted = false

    func setItemHighlighted(_ highlighted: Bool) {
        guard isItemHighlighted != highlighted else { return }
        isItemHighlighted = highlighted
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        if isItemHighlighted {
            NSColor.controlAccentColor.setFill()
            let insetRect = NSRect(
                x: bounds.origin.x + 4,
                y: bounds.origin.y,
                width: bounds.width - 8,
                height: bounds.height
            )
            let path = NSBezierPath(
                roundedRect: insetRect,
                xRadius: Const.btnRadius,
                yRadius: Const.btnRadius
            )
            path.fill()
        }
    }

    override func drawSelection(in _: NSRect) {}
}
