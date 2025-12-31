//
//  RichTextEditor.swift
//  Clipboard
//
//  Created by crown on 2025/12/28.
//

import AppKit
import SwiftUI

@MainActor
final class RichTextEditorCoordinator: NSObject {
    var text: Binding<NSAttributedString>
    weak var textView: NSTextView?

    init(text: Binding<NSAttributedString>) {
        self.text = text
        super.init()
    }

    // MARK: - Text Change Handler

    func handleTextChange() {
        guard let textView else { return }
        let newText = textView.attributedString()
        text.wrappedValue = newText
    }

    func currentContent() -> NSAttributedString {
        textView?.attributedString() ?? text.wrappedValue
    }

    // MARK: - Format Actions

    func applyFormat(_ action: FormatAction) {
        guard let textView,
              let textStorage = textView.textStorage
        else { return }

        let selectedRange = textView.selectedRange()
        guard selectedRange.length > 0 else { return }

        textStorage.beginEditing()

        switch action {
        case .bold:
            applyBold(to: textStorage, range: selectedRange)
        case .italic:
            applyItalic(to: textStorage, range: selectedRange)
        case .underline:
            applyUnderline(to: textStorage, range: selectedRange)
        case .strikethrough:
            applyStrikethrough(to: textStorage, range: selectedRange)
        }

        textStorage.endEditing()

        text.wrappedValue = textView.attributedString()
    }

    private func applyBold(to storage: NSTextStorage, range: NSRange) {
        storage.enumerateAttribute(.font, in: range, options: []) {
            value,
                subRange,
                _ in
            let currentFont =
                (value as? NSFont)
                    ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let fontManager = NSFontManager.shared

            let newFont: NSFont =
                if fontManager.traits(of: currentFont).contains(.boldFontMask) {
                    fontManager.convert(
                        currentFont,
                        toNotHaveTrait: .boldFontMask
                    )
                } else {
                    fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
                }

            storage.addAttribute(.font, value: newFont, range: subRange)
        }
    }

    private func applyItalic(to storage: NSTextStorage, range: NSRange) {
        storage.enumerateAttribute(.font, in: range, options: []) {
            value,
                subRange,
                _ in
            let currentFont =
                (value as? NSFont)
                    ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let fontManager = NSFontManager.shared

            let newFont: NSFont =
                if fontManager.traits(of: currentFont).contains(.italicFontMask) {
                    fontManager.convert(
                        currentFont,
                        toNotHaveTrait: .italicFontMask
                    )
                } else {
                    fontManager.convert(
                        currentFont,
                        toHaveTrait: .italicFontMask
                    )
                }

            storage.addAttribute(.font, value: newFont, range: subRange)
        }
    }

    private func applyUnderline(to storage: NSTextStorage, range: NSRange) {
        var hasUnderline = false

        storage.enumerateAttribute(.underlineStyle, in: range, options: []) {
            value,
                _,
                stop in
            if let style = value as? Int, style != 0 {
                hasUnderline = true
                stop.pointee = true
            }
        }

        if hasUnderline {
            storage.removeAttribute(.underlineStyle, range: range)
        } else {
            storage.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: range
            )
        }
    }

    private func applyStrikethrough(to storage: NSTextStorage, range: NSRange) {
        var hasStrikethrough = false

        storage.enumerateAttribute(.strikethroughStyle, in: range, options: []) { value, _, stop in
            if let style = value as? Int, style != 0 {
                hasStrikethrough = true
                stop.pointee = true
            }
        }

        if hasStrikethrough {
            storage.removeAttribute(.strikethroughStyle, range: range)
        } else {
            storage.addAttribute(
                .strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: range
            )
        }
    }
}

final class TextViewDelegateWrapper: NSObject, NSTextViewDelegate {
    private weak var coordinator: RichTextEditorCoordinator?

    init(coordinator: RichTextEditorCoordinator) {
        self.coordinator = coordinator
        super.init()
    }

    func textDidChange(_: Notification) {
        Task { @MainActor [weak self] in
            self?.coordinator?.handleTextChange()
        }
    }
}

/// 富文本编辑器
struct RichTextEditor: NSViewRepresentable {
    @Binding var text: NSAttributedString
    @Binding var coordinator: RichTextEditorCoordinator?

    func makeCoordinator() -> RichTextEditorCoordinator {
        RichTextEditorCoordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.importsGraphics = false
        textView.allowsImageEditing = false

        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 8, height: 8)

        let delegateWrapper = TextViewDelegateWrapper(
            coordinator: context.coordinator
        )
        objc_setAssociatedObject(
            textView,
            "delegateWrapper",
            delegateWrapper,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        textView.delegate = delegateWrapper

        context.coordinator.textView = textView

        if let textStorage = textView.textStorage {
            let adaptedText = Self.applyAdaptiveTextColor(to: text)
            textStorage.setAttributedString(adaptedText)
        }

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        Task { @MainActor in
            coordinator = context.coordinator
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        context.coordinator.textView = textView

        let currentText = textView.attributedString()
        if currentText !== text, currentText.string != text.string {
            let selectedRanges = textView.selectedRanges
            let adaptedText = Self.applyAdaptiveTextColor(to: text)
            textView.textStorage?.setAttributedString(adaptedText)
            textView.selectedRanges = selectedRanges
        }
    }

    /// 自适应字体颜色
    private static func applyAdaptiveTextColor(to attributedString: NSAttributedString) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableString.length)

        mutableString.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            if value == nil {
                mutableString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
            }
        }

        return mutableString
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var text = NSAttributedString(
        string: "Hello World\nThis is a test."
    )
    @Previewable @State var coordinator: RichTextEditorCoordinator?

    RichTextEditor(text: $text, coordinator: $coordinator)
        .frame(width: 400, height: 300)
}
