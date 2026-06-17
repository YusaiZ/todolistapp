import SwiftUI

/// 单个事件卡片：内容（最多3行）、标签 chip、单击编辑、弥散投影。
struct CardView: View {
    @EnvironmentObject var state: AppState
    let card: Card
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.content.isEmpty ? "（空）" : card.content)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineLimit(3)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            let cardTags = state.tags(for: card)
            if !cardTags.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(cardTags) { tag in
                        Text(tag.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(TagPalette.fg(tag.colorIndex))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(TagPalette.bg(tag.colorIndex))
                            )
                            .compositingGroup()
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
        // 弥散投影：y 轴下移，让卡片下方阴影更重、上方更淡，悬浮感更强。
        // 用语义投影色：浅色保留原淡冷蓝灰，深色用纯黑压暗、透明度降低，保持柔和。
        .shadow(color: Color.cardShadow.opacity(isHovered ? 0.16 : 0.09),
                radius: isHovered ? 16 : 10,
                x: 0, y: isHovered ? 12 : 7)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                state.deleteCard(id: card.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .onTapGesture { onTap() }
    }
}

/// 简易自动换行布局，用于标签 chip 横向流式排列。
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                // 换行
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, x - spacing)
        }
        let height = y + lineHeight
        return CGSize(width: totalWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth && x > bounds.minX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y),
                      proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
