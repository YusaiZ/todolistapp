import SwiftUI

/// 弹窗模式：新建 or 编辑已有卡片。
enum SheetMode {
    case create
    case edit(Card)
}

/// 新建 / 编辑卡片弹窗。
/// 标签输入框中输入 · 后实时过滤已有标签，点击建议即选中；回车创建/复用标签。
struct NewCardSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: SheetMode

    @State private var content: String = ""
    @State private var selectedTagIds: [UUID] = []
    @State private var tagInput: String = ""
    @State private var showSuggestions = false

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            Text(isEdit ? "编辑事件" : "新建事件")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            // 内容
            VStack(alignment: .leading, spacing: 6) {
                Text("内容")
                    .fieldLabel()
                TextEditor(text: $content)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 84)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.inputBorder, lineWidth: 1)
                    )
            }

            // 标签
            VStack(alignment: .leading, spacing: 6) {
                Text("标签")
                    .fieldLabel()

                // 已选标签 chip
                if !selectedTagIds.isEmpty {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(selectedTagIds, id: \.self) { id in
                            HStack(spacing: 4) {
                                Text(state.tagName(id))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color.secondaryEmphasis)
                                Button {
                                    selectedTagIds.removeAll { $0 == id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.leading, 8)
                            .padding(.trailing, 5)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.badgeFill))
                        }
                    }
                }

                // 标签输入框（输入 · 触发建议）
                ZStack(alignment: .topLeading) {
                    tagInputField

                    if showSuggestions && !currentSuggestions.isEmpty {
                        suggestionsList
                            .padding(.top, 34)
                    }
                }
                Text("输入 · 后可从已有标签中选择，或直接输入新标签后回车。")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            // 底部按钮
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEdit ? "保存" : "创建") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { configureForMode() }
    }

    // MARK: 子视图

    private var tagInputField: some View {
        TextField("输入 · 选择标签…", text: $tagInput, onCommit: { commitTagInput() })
            .font(.system(size: 13))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.inputBorder, lineWidth: 1)
            )
            .onChange(of: tagInput) { newValue in
                handleTagInputChange(newValue)
            }
    }

    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(currentSuggestions) { tag in
                let already = selectedTagIds.contains(tag.id)
                Button {
                    addTag(tag)
                } label: {
                    HStack {
                        Text(tag.name)
                            .font(.system(size: 12))
                            .foregroundColor(already ? .secondary : .primary)
                        Spacer()
                        if already {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(already)
                Divider()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
    }

    // MARK: 逻辑

    /// 当前应显示的建议：依据 tagInput 中 · 后的前缀过滤。
    private var currentSuggestions: [Tag] {
        let prefix = prefixAfterDot(from: tagInput)
        let pool = state.suggestTags(prefix: prefix)
        return pool
    }

    /// 从输入串里取出最后一个 · 之后的内容作为过滤前缀。
    private func prefixAfterDot(from text: String) -> String {
        guard let dotIndex = text.lastIndex(of: "·") else { return "" }
        let after = text.index(after: dotIndex)
        return String(text[after...])
    }

    private func handleTagInputChange(_ newValue: String) {
        // 只要出现 · 就展示建议。
        showSuggestions = newValue.contains("·")
    }

    private func addTag(_ tag: Tag) {
        if !selectedTagIds.contains(tag.id) {
            selectedTagIds.append(tag.id)
        }
        // 清掉 · 段落，保留其它文本便于继续输入。
        clearCurrentDotSegment()
        showSuggestions = false
    }

    /// 回车提交：取 · 后的词作为新标签名（若无 ·，整个输入当名字）。
    private func commitTagInput() {
        let name = prefixAfterDot(from: tagInput).trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = name.isEmpty ? fallback : name
        guard !final.isEmpty else { return }
        if let id = state.ensureTag(named: final), !selectedTagIds.contains(id) {
            selectedTagIds.append(id)
        }
        tagInput = ""
        showSuggestions = false
    }

    private func clearCurrentDotSegment() {
        if let dotIndex = tagInput.lastIndex(of: "·") {
            tagInput = String(tagInput[..<dotIndex])
        } else {
            tagInput = ""
        }
        tagInput = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func configureForMode() {
        if case .edit(let card) = mode {
            content = card.content
            selectedTagIds = card.tagIds
        }
    }

    private func commit() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 若输入框还有未提交的标签，一并收纳。
        if !tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            commitTagInput()
        }
        switch mode {
        case .create:
            state.addCard(content: trimmed, tagIds: selectedTagIds)
        case .edit(let card):
            state.updateCard(id: card.id, content: trimmed, tagIds: selectedTagIds)
        }
        dismiss()
    }
}

private extension View {
    func fieldLabel() -> some View {
        self
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
}
