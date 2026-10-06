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
            make.width.height.equalTo(config.iconContainerSize)
        }
        dotView.wantsLayer = true
        dotContainerView.addSubview(dotView)
        dotView.snp.makeConstraints { make in
            make.width.height.equalTo(config.smallIconPt)
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
        if config.compact {
            let inset: CGFloat = config.dotMode ? Const.space4 : Const.space6
            return NSEdgeInsets(
                top: haloInset + Const.space4,
                left: haloInset + inset,
                bottom: haloInset + Const.space4,
                right: haloInset + inset
            )
        }
        let horizontalInset: CGFloat =
            config.dotMode ? Const.space6 : Const.space10
        return NSEdgeInsets(
            top: haloInset + Const.space6,
            left: haloInset + horizontalInset,
            bottom: haloInset + Const.space6,
            right: haloInset + horizontalInset
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
            ofSize: config.labelFontSize,
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
        nameField.containerCornerRadius = config.compact ? Const.btnRadius : Const.radius
        nameField.onFocusChange = { [weak self] focused in
            self?.handleNameFieldFocusChange(focused)
        }

    }
}
