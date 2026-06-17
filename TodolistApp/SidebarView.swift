import SwiftUI

/// 左侧标签栏：显示「全部」与各标签及其数量，点击切换筛选。
struct SidebarView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("标签")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                // 全部
                rowButton(title: "全部", count: state.cards.count, colorIndex: nil, isSelected: state.selectedTagId == nil) {
                    state.selectedTagId = nil
                }
                .padding(.horizontal, 8)

                Divider()
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)

                // 只显示至少关联一个事件的标签；事件全删则自动隐藏。
                ForEach(state.tags.filter { state.count(forTag: $0.id) > 0 }) { tag in
                    rowButton(title: tag.name, count: state.count(forTag: tag.id),
                              colorIndex: tag.colorIndex,
                              isSelected: state.selectedTagId == tag.id) {
                        state.selectedTagId = tag.id
                    }
                    .padding(.horizontal, 8)
                }

                if state.tags.filter({ state.count(forTag: $0.id) > 0 }).isEmpty {
                    Text("暂无标签\n新建事件时输入 · 即可创建")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func rowButton(title: String, count: Int, colorIndex: Int?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor(colorIndex, isSelected: isSelected))
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.badgeFill)
                    )
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.selectedRowFill : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 「全部」用中性灰点；具体标签用调色板颜色（已随外观自适应）。
    private func dotColor(_ colorIndex: Int?, isSelected: Bool) -> Color {
        if let idx = colorIndex {
            return TagPalette.fg(idx)
        }
        return isSelected ? Color.primary : Color.gray.opacity(0.45)
    }
}
