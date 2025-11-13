//
//  RichTextView.swift
//  Clipboard
//
//  Created by You on 2025/9/26.
//

import SwiftUI

struct RichTextView: View, Equatable {
    let attributedString: AttributedString

    init(attributedString: AttributedString) {
        self.attributedString = attributedString
    }

    var body: some View {
        Text(attributedString)
            .lineLimit(12)
            .multilineTextAlignment(.leading)
            .textSelection(.disabled)
    }

    static func == (lhs: RichTextView, rhs: RichTextView) -> Bool {
        lhs.attributedString == rhs.attributedString
    }
}
