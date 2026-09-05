import AppKit

final class FloatingCollectionItem: NSCollectionViewItem {
    static let id = NSUserInterfaceItemIdentifier("FloatingCollectionItem")

    private var isFocused = true
    let cardView = FloatingCardRowView()

    override func loadView() {
        view = cardView
    }

    func configure(
        with model: PasteboardModel,
        keyword: String,
        isFocused: Bool,
        quickPasteIndex: Int?
    ) {
        self.isFocused = isFocused
        cardView.configure(
            with: model,
            keyword: keyword,
            isSelected: isSelected,
            isFocused: isFocused,
            quickPasteIndex: quickPasteIndex
        )
    }

    func setFocused(_ focused: Bool) {
        isFocused = focused
        cardView.updateSelection(isSelected: isSelected, isFocused: focused)
    }

    func setQuickPasteIndex(_ index: Int?) {
        cardView.quickPasteIndex = index
    }

    func setShowPlainTextIndicator(_ show: Bool) {
        cardView.showPlainTextIndicator = show
    }

    override var isSelected: Bool {
        didSet {
            cardView.updateSelection(
                isSelected: isSelected,
                isFocused: isFocused
            )
        }
    }

    var onPaste: (() -> Void)? {
        get { cardView.onPaste }
        set { cardView.onPaste = newValue }
    }

    var onPastePlainText: (() -> Void)? {
        get { cardView.onPastePlainText }
        set { cardView.onPastePlainText = newValue }
    }

    var onCopy: (() -> Void)? {
        get { cardView.onCopy }
        set { cardView.onCopy = newValue }
    }

    var onEdit: (() -> Void)? {
        get { cardView.onEdit }
        set { cardView.onEdit = newValue }
    }

    var onDelete: (() -> Void)? {
        get { cardView.onDelete }
        set { cardView.onDelete = newValue }
    }

    var onTogglePreview: (() -> Void)? {
        get { cardView.onTogglePreview }
        set { cardView.onTogglePreview = newValue }
    }

    var onAssignToChip: ((Int) -> Void)? {
        get { cardView.onAssignToChip }
        set { cardView.onAssignToChip = newValue }
    }

    var onCreateChip: ((PasteboardModel) -> Void)? {
        get { cardView.onCreateChip }
        set { cardView.onCreateChip = newValue }
    }
}
