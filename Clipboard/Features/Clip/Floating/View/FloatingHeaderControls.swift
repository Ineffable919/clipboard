import AppKit
import Combine
import SnapKit

// MARK: - FloatingDragHandle

final class FloatingDragHandle: NSView {
    private let pill = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 2
        addSubview(pill)
        pill.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(36)
            make.height.equalTo(4)
        }
        updateColor()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColor()
    }

    private func updateColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            pill.layer?.backgroundColor = NSColor.secondaryLabelColor
                .withAlphaComponent(0.3).cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - FloatingSearchField

final class FloatingSearchField: NSSearchField {
    @Published private(set) var text: String = ""
    var onBecomeFirstResponder: (() -> Void)?

    override var stringValue: String {
        didSet {
            if stringValue != text {
                text = stringValue
            }
        }
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        text = stringValue
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        placeholderString = String(localized: .search)
        controlSize = .large
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            onBecomeFirstResponder?()
        }
        return result
    }
}

// MARK: - FloatingPinButton

final class FloatingPinButton: NSButton {
    private(set) var isPinned = false {
        didSet { updateAppearance() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private func setup() {
        isBordered = false
        imageScaling = .scaleNone
        target = self
        action = #selector(toggle)
        toolTip = String(localized: .pin)
        updateAppearance()
    }

    @objc private func toggle() {
        isPinned.toggle()
        ClipFloatingWindowController.shared.isPinned = isPinned
        toolTip = String(localized: isPinned ? .unpin : .pin)
    }

    private func updateAppearance() {
        let symbolName = isPinned ? "pin.fill" : "pin"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        contentTintColor = isPinned ? .controlAccentColor : .secondaryLabelColor
    }
}
