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

    @State private var title: String = ""
    @State private var detail: String = ""
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

            // 标题
            VStack(alignment: .leading, spacing: 6) {
                Text("标题")
                    .fieldLabel()
                NoFocusTextField(text: $title, placeholder: "一句话概括这件事", font: .systemFont(ofSize: 15))
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
            }

            // 详情
            VStack(alignment: .leading, spacing: 6) {
                Text("详情")
                    .fieldLabel()
                TextEditor(text: $detail)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 160, alignment: .top)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.inputBorder, lineWidth: 1)
                    )
                    .focusEffectDisabled()
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 620, height: 680)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { configureForMode() }
    }

    // MARK: 子视图

    private var tagInputField: some View {
        NoFocusTextField(
            text: $tagInput,
            placeholder: "输入 · 选择标签…",
            font: .systemFont(ofSize: 15),
            onCommit: { commitTagInput() }
        )
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
            title = card.title
            detail = card.detail
            selectedTagIds = card.tagIds
        }
    }

    private func commit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        // 若输入框还有未提交的标签，一并收纳。
        if !tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            commitTagInput()
        }
        switch mode {
        case .create:
            state.addCard(title: trimmedTitle, detail: detail, tagIds: selectedTagIds)
        case .edit(let card):
            state.updateCard(id: card.id, title: trimmedTitle, detail: detail, tagIds: selectedTagIds)
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

/// 无聚焦框的单行文本框。
/// SwiftUI 的 TextField 底层是 NSTextField，会自己画系统强调色（蓝）聚焦框，
/// `.focusEffectDisabled()` 管不到它。这里直接包装 NSTextField，把 focusRingType 设为 .none，
/// 并关闭原生边框/背景（改由外层 SwiftUI 的 .background/.overlay 绘制），从 AppKit 层彻底关掉蓝框。
struct NoFocusTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var font: NSFont = .systemFont(ofSize: 13)
    /// 回车提交（用于标签输入框）。主线程派发，避免在 SwiftUI 视图更新中改状态。
    var onCommit: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSTextField {
        let field = ClickableTextField()
        field.focusRingType = .none          // 关键：关闭聚焦框
        field.isBezeled = false              // 关原生边框，交给外层 SwiftUI overlay
        field.drawsBackground = false        // 关原生背景，交给外层 SwiftUI background
        field.isEditable = true
        field.isSelectable = true
        field.font = font
        field.placeholderString = placeholder
        field.stringValue = text
        field.delegate = context.coordinator
        // 选中时文字颜色保持正常，避免系统把选区染成强调色。
        field.textColor = NSColor.labelColor
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // 外部（如建议点击清空）改了 binding，同步回控件。
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        nsView.font = font
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: NoFocusTextField
        init(_ parent: NoFocusTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        // 仅回车键触发 onCommit，与原 SwiftUI TextField.onCommit 语义一致（失焦不触发）。
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit?()
                return true
            }
            return false
        }
    }
}

/// 无聚焦框的多行文本编辑器（包装 NSTextView）。
/// 注意：当前未启用（详情改回 SwiftUI TextEditor，保证点击编辑稳定可靠）。
/// 保留实现，待后续需要「编辑时光标自动到末尾」等 TextEditor 做不到的能力时再启用。
struct NoFocusTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 15)
    var moveCursorToEndOnAppear: Bool = false

    func makeNSView(context: Context) -> NSScrollView {
        let textView = ClickableTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = font
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 8
        textView.insertionPointColor = NSColor.labelColor
        textView.string = text
        textView.delegate = context.coordinator

        if moveCursorToEndOnAppear {
            let end = text.utf16.count
            textView.setSelectedRange(NSRange(location: end, length: 0))
            textView.scrollRangeToVisible(NSRange(location: end, length: 0))
        }

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text { textView.string = text }
        textView.font = font
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: NoFocusTextView
        init(_ parent: NoFocusTextView) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// NSTextField 子类：嵌入 SwiftUI 后，原生点击聚焦有时失效；
/// 这里手动拦截 mouseDown，确保点击后立刻成为第一响应者（获得光标、可编辑）。
final class ClickableTextField: NSTextField {
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

/// NSTextView 子类：同上，确保点击详情区能立刻获得光标。
final class ClickableTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}
