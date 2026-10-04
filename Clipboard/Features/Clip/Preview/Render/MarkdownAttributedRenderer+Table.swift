//
//  MarkdownAttributedRenderer+Table.swift
//  Clipboard
//
//  Markdown 富文本表格渲染。
//

import AppKit
import Markdown

extension MarkdownAttributedRenderer {
    mutating func visitTable(_ table: Markdown.Table) -> NSAttributedString {
        let textTable = NSTextTable()
        textTable.numberOfColumns = table.maxColumnCount

        let result = NSMutableAttributedString()
        var rowIndex = 0

        appendTableRow(
            cells: Array(table.head.cells),
            row: rowIndex,
            isHeader: true,
            table: textTable,
            into: result
        )
        rowIndex += 1

        for row in table.body.rows {
            appendTableRow(
                cells: Array(row.cells),
                row: rowIndex,
                isHeader: false,
                table: textTable,
                into: result
            )
            rowIndex += 1
        }

        result.append(blockTerminator())
        return result
    }

    private mutating func appendTableRow(
        cells: [Markdown.Table.Cell],
        row: Int,
        isHeader: Bool,
        table: NSTextTable,
        into result: NSMutableAttributedString
    ) {
        for column in 0 ..< table.numberOfColumns {
            let block = NSTextTableBlock(
                table: table,
                startingRow: row,
                rowSpan: 1,
                startingColumn: column,
                columnSpan: 1
            )
            block.setBorderColor(.separatorColor)
            block.setWidth(1, type: .absoluteValueType, for: .border)
            block.setWidth(Const.space6, type: .absoluteValueType, for: .padding)
            if isHeader {
                block.backgroundColor = .quaternaryLabelColor
            }

            let style = NSMutableParagraphStyle()
            style.textBlocks = [block]

            let cellContent: NSMutableAttributedString = if column < cells.count {
                inlineChildren(of: cells[column])
            } else {
                NSMutableAttributedString()
            }
            if cellContent.length == 0 {
                cellContent.append(NSAttributedString(string: " ", attributes: baseAttributes()))
            }
            if isHeader {
                cellContent.addAttribute(
                    .font,
                    value: NSFont.systemFont(ofSize: baseFontSize, weight: .semibold),
                    range: NSRange(location: 0, length: cellContent.length)
                )
            }
            cellContent.addAttribute(
                .paragraphStyle,
                value: style,
                range: NSRange(location: 0, length: cellContent.length)
            )
            cellContent.append(NSAttributedString(string: "\n"))
            result.append(cellContent)
        }
    }
}
