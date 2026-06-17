import SwiftUI
import AppKit

/// 右侧看板：顶部新建按钮 + 四列。
struct BoardView: View {
    @EnvironmentObject var state: AppState
    @Binding var showNewCard: Bool
    @Binding var editingCard: Card?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().frame(height: 1)
            // 四列自适应宽度：不用横向滚动，窗口缩小时列与卡片一起变窄。
            HStack(alignment: .top, spacing: 8) {
                ForEach(Status.allCases, id: \.self) { status in
                    ColumnView(status: status, editingCard: $editingCard)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Color.appBackground)
        .background(returnShortcutButton)
    }

    /// 不可见按钮，仅用于承载「按 Return（回车）打开新建弹窗」快捷键。
    /// 放在背景层不占空间，也不可点击；键盘事件由窗口统一派发。
    /// 当 NewCardSheet 弹出后焦点转移，回车由 sheet 处理，不会重复触发。
    private var returnShortcutButton: some View {
        Button(action: { showNewCard = true }) {
            Color.clear
        }
        .keyboardShortcut(.return, modifiers: [])
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: { showNewCard = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("新建")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color.accentButtonText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(Color.accentButtonBg)
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)

            if let id = state.selectedTagId {
                HStack(spacing: 6) {
                    Text("筛选：")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(state.tagName(id))
                        .font(.system(size: 12, weight: .medium))
                    Button {
                        state.selectedTagId = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Text("\(state.cards.count) 个事件")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            appearanceMenu
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appBackground)
    }

    /// 右上角外观切换菜单：跟随系统 / 浅色 / 深色 三选一。
    private var appearanceMenu: some View {
        Menu {
            Picker("外观", selection: $state.appearance) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: state.appearance.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("外观：\(state.appearance.label)")
    }
}

/// 单列：标题、数量、可滚动卡片列表、拖放目标。
struct ColumnView: View {
    @EnvironmentObject var state: AppState
    let status: Status
    @Binding var editingCard: Card?

    @State private var isDropTargeted = false

    private var columnCards: [Card] { state.cards(in: status) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(columnCards) { card in
                        CardView(card: card) {
                            editingCard = card
                        }
                        .draggable(card.id.uuidString)
                    }
                }
                // 卡片两边留白：比列窄一点。
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 20)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.columnFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDropTargeted ? Color.accentButtonBg.opacity(0.35) : Color.clear,
                    lineWidth: 2
                )
        )
        .dropDestination(for: String.self) { items, _ in
            guard let s = items.first, let id = UUID(uuidString: s) else { return false }
            let moved = (state.cards.first { $0.id == id })?.status != status
            state.move(cardId: id, to: status)
            if moved {
                Sound.playDrop()
            }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(status.title)
                .font(.system(size: 14, weight: .semibold))
            Text("\(columnCards.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)   // 计数
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.badgeFill))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

/// 拖放吸附音效（系统提示音）。
enum Sound {
    static func playDrop() {
        // Funk：轻巧柔和的「咚」声，适合吸附反馈；找不到时静默兜底。
        NSSound(named: "Funk")?.play()
    }
}
