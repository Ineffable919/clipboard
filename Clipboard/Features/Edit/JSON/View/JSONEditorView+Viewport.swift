import AppKit
import SnapKit

extension JSONEditorView {
    func makeViewport() -> JSONViewportEditor {
        let editor = JSONViewportEditor()
        editor.indentation = indentation
        editor.onCursor = { [weak self] line, column in self?.onCursorChange?(line, column) }
        editor.onChange = { [weak self] lines in
            self?.knownValidity = nil
            self?.onTextChange?(lines)
        }
        addSubview(editor)
        editor.snp.makeConstraints { $0.edges.equalToSuperview() }
        return editor
    }

    @discardableResult
    func replaceViewport(
        _ text: String, replacement: JSONViewportReplacement, viewport: JSONViewportEditor?
    ) -> Bool {
        guard !(replacement.previousText as NSString).isEqual(to: text) else { return false }
        if !replacement.entireDocument, let viewport {
            viewport.replace(text, in: replacement.range, registeringUndo: replacement.registeringUndo)
            knownValidity = nil
            return true
        }
        if replacement.registeringUndo {
            let previousText = replacement.previousText
            let previousValidity = replacement.previousValidity
            let validity = replacement.validity
            undoManager?.registerUndo(withTarget: self) { target in
                target.restoreDocument(
                    previousText, validity: previousValidity,
                    reversing: text, oppositeValidity: validity
                )
            }
        }
        setText(text, document: replacement.index, preparedText: replacement.prepared, resettingUndo: false)
        knownValidity = replacement.validity
        onTextChange?(replacement.index?.statisticsLineCount)
        return true
    }
}
