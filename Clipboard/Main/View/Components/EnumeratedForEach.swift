//
//  EnumeratedForEach.swift
//  Clipboard
//
//  Created by crown on 2026/2/12.
//

import SwiftUI

struct EnumeratedForEach<Data: RandomAccessCollection, Content: View>: View
    where Data.Element: Identifiable
{
    let data: Data
    let content: (Int, Data.Element) -> Content

    init(
        _ data: Data,
        @ViewBuilder content: @escaping (Int, Data.Element) -> Content
    ) {
        self.data = data
        self.content = content
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            ForEach(data.enumerated(), id: \.element.id) { index, item in
                content(index, item)
            }
        } else {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                content(index, item)
            }
        }
    }
}
