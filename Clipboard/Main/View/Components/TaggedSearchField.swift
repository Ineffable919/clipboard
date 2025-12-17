import SwiftUI

struct SearchTag: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let icon: String?

    init(title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }
}

/// 类似 Spotlight 的标签搜索输入框
struct TaggedSearchField: View {
    @Binding var tags: [SearchTag]
    @Binding var text: String
    @FocusState private var isFocused: Bool

    let placeholder: String
    let onSubmit: () -> Void
    let onDeleteTag: ((SearchTag) -> Void)?

    init(
        tags: Binding<[SearchTag]>,
        text: Binding<String>,
        placeholder: String = "搜索...",
        onSubmit: @escaping () -> Void = {},
        onDeleteTag: ((SearchTag) -> Void)? = nil
    ) {
        self._tags = tags
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onDeleteTag = onDeleteTag
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Const.iconHdSize, weight: .regular))
                .foregroundColor(.secondary)
                .padding(.leading, 6)
                .frame(width: 24)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6.0) {
                        // 标签列表
                        ForEach(tags) { tag in
                            TagChipView(tag: tag) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    tags.removeAll { $0.id == tag.id }
                                    onDeleteTag?(tag)
                                }
                            }
                            .id(tag.id)
                        }
                        // 文本输入框
                        TextField(
                            tags.isEmpty ? placeholder : "",
                            text: $text
                        )
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .padding(.trailing)
                        .onSubmit {
                            onSubmit()
                        }
                        .autoScrollOnIMEInput {
                            scrollToEnd(proxy)
                        }
                        .id("textfield")
                    }
                    .padding(.vertical, 8.0)
                    .padding(.horizontal, 6.0)
                }
                .onChange(of: tags.count) {
                    scrollToEnd(proxy)
                }
                .onChange(of: text) {
                    scrollToEnd(proxy)
                }
                .onChange(of: isFocused) { _, newValue in
                    if newValue {
                        scrollToEnd(proxy)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Const.radius)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Const.radius)
                .strokeBorder(
                    isFocused ? Color.accentColor.opacity(0.4) : Color.clear,
                    lineWidth: 3
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Const.radius)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .onTapGesture {
            isFocused = true
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        proxy.scrollTo("textfield", anchor: .trailing)
    }
}

struct TagChipView: View {
    let tag: SearchTag
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4.0) {
            if let icon = tag.icon {
                Image(systemName: icon)
                    .font(.system(size: 11))
            }

            Text(tag.title)
                .font(.system(size: 12))
                .lineLimit(1)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Const.space4)
        .padding(.horizontal, Const.space8)
        .background(
            RoundedRectangle(cornerRadius: Const.radius)
                .fill(Color.accentColor.opacity(0.2))
        )

    }
}

// MARK: - Preview
#Preview {
    TaggedSearchFieldExample()
        .padding(40)
        .frame(width: 600, height: 300)
}

struct TaggedSearchFieldExample: View {
    @State private var tags: [SearchTag] = [
        SearchTag(title: "Xcode", icon: "hammer.fill"),
        SearchTag(title: "Swift", icon: "swift"),
    ]
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("类似 Spotlight 的搜索框")
                .font(.headline)

            TaggedSearchField(
                tags: $tags,
                text: $searchText,
                placeholder: "搜索应用、文档...",
                onSubmit: {
                    if !searchText.isEmpty {
                        tags.append(
                            SearchTag(title: searchText, icon: "tag.fill")
                        )
                        searchText = ""
                    }
                },
                onDeleteTag: { tag in
                    print("删除标签: \(tag.title)")
                }
            )

            Text("提示: 输入文字后按回车添加标签")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
