import AppKit
import SnapKit
import SwiftUI

extension ChipButton {
    func updateContent() {
        for arrangedSubview in stack.arrangedSubviews {
            stack.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }
        nameFieldWidthConstraint?.deactivate()
        nameFieldWidthConstraint = nil

        // 仅新增态允许点击圆点切换颜色
        dotClickGestureRecognizer.isEnabled = canCycleColor

        stack.snp.remakeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }

        if config.dotMode {
            if config.chip.isSystem {
                addSystemClockIcon(pointSize: config.smallIconPt, weight: .medium)
            } else {
                configureDot(colorIndex: config.chip.colorIndex)
                stack.addArrangedSubview(dotContainerView)
            }
            invalidateIntrinsicContentSize()
            return
        }

        if !config.compact {
            if config.chip.id == -1 {
                addSystemClockIcon(pointSize: config.iconContainerSize, weight: .regular)
            } else {
                let colorIndex =
                    config.isEditing
                        ? config.editingColorIndex : config.chip.colorIndex
                configureDot(colorIndex: colorIndex)
                stack.addArrangedSubview(dotContainerView)
            }
        }

        nameField.stringValue = displayedName
        nameField.isEditable = config.isEditing
        nameField.isSelectable = config.isEditing
        clickGestureRecognizer.isEnabled = !config.isEditing
        stack.addArrangedSubview(nameField)
        nameField.snp.remakeConstraints { make in
            nameFieldWidthConstraint =
                make.width.equalTo(nameFieldDisplayWidth()).constraint
        }

        if config.isEditing {
            didHandleEditingCompletion = false
            Task { @MainActor [weak self] in
                guard let self, config.isEditing else { return }
                window?.makeFirstResponder(nameField)
                nameField.moveCursorToEnd()
            }
        }

        invalidateIntrinsicContentSize()
    }

    func addSystemClockIcon(pointSize: CGFloat, weight: NSFont.Weight) {
        let symbolName = if #available(macOS 15.0, *) {
            "clock.arrow.trianglehead.counterclockwise.rotate.90"
        } else {
            "clock.arrow.circlepath"
        }
        let icon = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        iconImageView.image = icon?.withSymbolConfiguration(.init(pointSize: pointSize, weight: weight))
        iconImageView.snp.remakeConstraints { make in
            make.width.height.equalTo(config.iconContainerSize)
        }
        stack.addArrangedSubview(iconImageView)
    }

    func nameFieldDisplayWidth() -> CGFloat {
        let font = nameField.font ?? .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let text = displayedName.isEmpty ? " " : displayedName
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        return ceil(width)
    }

    func configureDot(colorIndex: Int) {
        let index = min(max(colorIndex, 0), CategoryChip.palette.count - 1)
        CategoryDotRenderer.configure(
            dotView,
            colorIndex: index,
            diameter: config.dotRadius * 2
        )
    }

    func updateAppearance(animated: Bool) {
        var resolvedBgCGColor: CGColor = .clear
        var resolvedFgColor: NSColor = .labelColor

        effectiveAppearance.performAsCurrentDrawingAppearance {
            resolvedBgCGColor = resolvedBackgroundColor().cgColor
            resolvedFgColor = resolvedForegroundColor()
        }

        nameField.textColor = resolvedFgColor
        iconImageView.contentTintColor = resolvedFgColor

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.allowsImplicitAnimation = true
                self.backgroundLayer.backgroundColor = resolvedBgCGColor
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            backgroundLayer.backgroundColor = resolvedBgCGColor
            CATransaction.commit()
        }
    }

    func resolvedBackgroundColor() -> NSColor {
        let isDark =
            effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        if config.dotMode {
            return dotBackgroundColor(isDark: isDark)
        }

        let isFrostedGlass: Bool = {
            if #available(macOS 26, *) {
                return false
            }
            return true
        }()

        if config.compact {
            let chipColor = compactChipColor()
            if config.isSelected || config.isEditing {
                return chipColor
            }
            if isHovering || isDraggingOver {
                if isDark && isFrostedGlass {
                    return NSColor(white: 1.0, alpha: 0.10)
                }
                return isDark
                    ? .quaternaryLabelColor
                    : .labelColor.withAlphaComponent(0.08)
            }
            return .clear
        }

        if config.isSelected || config.isEditing {
            if isDark && isFrostedGlass {
                return NSColor(white: 1.0, alpha: 0.2)
            }
            return isDark ? .quaternaryLabelColor : .labelColor.withAlphaComponent(0.1)
        }

        if isHovering || isDraggingOver {
            if isDark && isFrostedGlass {
                return NSColor(white: 1.0, alpha: 0.10)
            }
            return isDark
                ? .quaternaryLabelColor.withAlphaComponent(0.06)
                : .labelColor.withAlphaComponent(0.06)
        }

        return .clear
    }

    private func dotBackgroundColor(isDark: Bool) -> NSColor {
        if isDraggingOver || isHovering {
            return isDark ? .quaternaryLabelColor : .labelColor.withAlphaComponent(0.06)
        }
        return .clear
    }

    func compactChipColor() -> NSColor {
        config.chip.id == -1
            ? .controlAccentColor
            : CategoryChip.nsColor(at: config.chip.colorIndex)
    }

    func resolvedForegroundColor() -> NSColor {
        if config.compact, config.isSelected || config.isEditing {
            return .white
        }
        return .labelColor.withAlphaComponent(0.85)
    }

    override var intrinsicContentSize: NSSize {
        let fitting = stack.fittingSize
        return NSSize(
            width: fitting.width + contentInsets.left + contentInsets.right,
            height: fitting.height + contentInsets.top + contentInsets.bottom
        )
    }

    override func layout() {
        super.layout()

        let pillFrame = bounds.insetBy(dx: haloInset, dy: haloInset)
        backgroundLayer.frame = pillFrame
        if #available(macOS 26.0, *), config.compact {
            backgroundLayer.cornerRadius = max(0, pillFrame.height / 2)
        } else {
            backgroundLayer.cornerRadius = config.compact ? Const.btnRadius : Const.radius
        }
        if nameField.containerCornerRadius != backgroundLayer.cornerRadius {
            nameField.containerCornerRadius = backgroundLayer.cornerRadius
            nameField.noteFocusRingMaskChanged()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance(animated: false)

        let colorIndex =
            config.isEditing
                ? config.editingColorIndex : config.chip.colorIndex
        if !config.chip.isSystem || !config.dotMode {
            configureDot(colorIndex: colorIndex)
        }
    }

}
