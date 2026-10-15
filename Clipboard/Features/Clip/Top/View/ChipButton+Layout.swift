import AppKit
import SnapKit

extension ChipButton {
    // MARK: - Setup

    func setup() {
        wantsLayer = true

        backgroundLayer.masksToBounds = true
        layer?.addSublayer(backgroundLayer)

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = Const.space6
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }

        iconImageView.imageScaling = .scaleProportionallyDown

        dotContainerView.snp.makeConstraints { make in
            make.width.height.equalTo(config.size.iconContainerSize)
        }
        dotView.wantsLayer = true
        dotContainerView.addSubview(dotView)
        dotView.snp.makeConstraints { make in
            make.width.height.equalTo(config.size.smallIconPt)
            make.center.equalToSuperview()
        }

        setupNameField()

        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [
                    .mouseEnteredAndExited, .activeAlways, .inVisibleRect
                ],
                owner: self,
                userInfo: nil
            )
        )

        addGestureRecognizer(clickGestureRecognizer)
        dotContainerView.addGestureRecognizer(dotClickGestureRecognizer)

        registerForDraggedTypes(PasteboardType.supportTypes)
    }

    var contentInsets: NSEdgeInsets {
        let insets = config.size.contentInsets(dotMode: config.dotMode)
        return NSEdgeInsets(
            top: haloInset + insets.top,
            left: haloInset + insets.left,
            bottom: haloInset + insets.bottom,
            right: haloInset + insets.right
        )
    }

    var displayedName: String {
        if config.isEditing {
            return config.editingName
        }
        return config.chip.name
    }

    var canCycleColor: Bool {
        config.isEditing && config.allowsColorCycling
            && !config.dotMode && !config.chip.isSystem
    }

    private func setupNameField() {
        nameField.delegate = self
        nameField.font = .systemFont(
            ofSize: config.size.labelFontSize,
            weight: .regular
        )
        nameField.isBordered = false
        nameField.drawsBackground = false
        nameField.maximumNumberOfLines = 1
        nameField.lineBreakMode = .byClipping
        nameField.cell?.isScrollable = false
        nameField.cell?.wraps = false
        nameField.cell?.usesSingleLineMode = true
        nameField.setContentHuggingPriority(.required, for: .horizontal)
        nameField.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
        nameField.focusRingMaskView = self
        nameField.containerCornerRadius = config.size.cornerRadius
        nameField.onFocusChange = { [weak self] focused in
            self?.handleNameFieldFocusChange(focused)
        }

    }
}
