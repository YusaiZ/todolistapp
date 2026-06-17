import Foundation
import SwiftUI

/// 全局状态：卡片、标签、筛选条件；负责增删改与持久化。
final class AppState: ObservableObject {

    @Published var cards: [Card] { didSet { scheduleSave() } }
    @Published var tags: [Tag] { didSet { scheduleSave() } }

    /// 当前筛选的标签 id；nil 表示显示全部。
    @Published var selectedTagId: UUID? = nil

    /// 外观偏好（跟随系统 / 浅色 / 深色）。持久化到 UserDefaults，缺省 .auto。
    @Published var appearance: AppearanceMode {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }

    init() {
        let data = Persistence.load()
        self.cards = data.cards.sorted { lhs, rhs in
            if lhs.status != rhs.status { return false }
            return lhs.order < rhs.order
        }
        self.tags = data.tags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        // 读取外观偏好；非法值兜底为 .auto。
        let raw = UserDefaults.standard.string(forKey: "appearance") ?? AppearanceMode.auto.rawValue
        self.appearance = AppearanceMode(rawValue: raw) ?? .auto
        // 不触发首次 didSet 的保存。
    }

    // MARK: - 持久化（防抖）

    private var saveTask: DispatchWorkItem?
    private func scheduleSave() {
        saveTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Persistence.save(StoreData(cards: self.cards, tags: self.tags))
        }
        saveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    /// 立即落盘（用于退出前等场景）。
    func flush() {
        saveTask?.cancel()
        Persistence.save(StoreData(cards: cards, tags: tags))
    }

    // MARK: - 卡片查询

    /// 某列下、应用当前筛选后的卡片（按 order 升序）。
    func cards(in status: Status) -> [Card] {
        cards.filter { $0.status == status && matchesFilter($0) }
            .sorted { $0.order < $1.order }
    }

    private func matchesFilter(_ card: Card) -> Bool {
        guard let id = selectedTagId else { return true }
        return card.tagIds.contains(id)
    }

    /// 某标签下的卡片总数（忽略筛选与状态）。
    func count(forTag id: UUID) -> Int {
        cards.filter { $0.tagIds.contains(id) }.count
    }

    // MARK: - 卡片增删改

    /// 新建卡片。
    @discardableResult
    func addCard(content: String, tagIds: [UUID], status: Status = .plan) -> Card {
        let nextOrder = (cards.filter { $0.status == status }.map(\.order).max() ?? -1) + 1
        let card = Card(content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                        tagIds: tagIds,
                        status: status,
                        order: nextOrder)
        cards.append(card)
        return card
    }

    /// 更新已有卡片的内容与标签。
    func updateCard(id: UUID, content: String, tagIds: [UUID]) {
        guard let idx = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[idx].content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        cards[idx].tagIds = tagIds
    }

    /// 删除卡片。
    func deleteCard(id: UUID) {
        cards.removeAll { $0.id == id }
    }

    /// 拖拽：把卡片移动到目标列（插到列尾），并重新整理该列 order。
    func move(cardId: UUID, to status: Status) {
        guard let idx = cards.firstIndex(where: { $0.id == cardId }) else { return }
        guard cards[idx].status != status else { return }
        cards[idx].status = status
        let nextOrder = (cards.filter { $0.status == status }.map(\.order).max() ?? -1) + 1
        cards[idx].order = nextOrder
        normalize(status: status)
    }

    /// 把某列的 order 重新压成连续整数，避免长期使用后空洞。
    private func normalize(status: Status) {
        var ordered = cards.filter { $0.status == status }.sorted { $0.order < $1.order }
        for (i, _) in ordered.enumerated() {
            if let idx = cards.firstIndex(where: { $0.id == ordered[i].id }) {
                cards[idx].order = i
                ordered[i].order = i
            }
        }
    }

    // MARK: - 标签管理

    /// 按名字查找已有标签（大小写不敏感）。
    func findTag(name: String) -> Tag? {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return tags.first { $0.name.lowercased() == t.lowercased() }
    }

    /// 创建标签（若已存在同名则返回已有），并返回其 id。
    /// 新建时按当前标签总数分配调色板索引，让颜色尽量分散。
    @discardableResult
    func ensureTag(named name: String) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existed = findTag(name: trimmed) { return existed.id }
        let colorIndex = tags.count % TagPalette.swatches.count
        let tag = Tag(name: trimmed, colorIndex: colorIndex)
        tags.append(tag)
        tags.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return tag.id
    }

    /// 用于输入触发符后实时过滤已有标签建议。
    /// 只返回至少关联一个事件的标签；事件全删的标签自动不出现。
    func suggestTags(prefix: String, limit: Int = 6) -> [Tag] {
        let active = tags.filter { count(forTag: $0.id) > 0 }
        let p = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if p.isEmpty {
            return Array(active.prefix(limit))
        }
        return active
            .filter { $0.name.lowercased().contains(p) }
            .prefix(limit)
            .map { $0 }
    }

    /// 某卡片对应的标签对象（按 tags 顺序）。
    func tags(for card: Card) -> [Tag] {
        let map = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
        return card.tagIds.compactMap { map[$0] }
    }

    /// 标签名 → id 的便捷查找。
    func tagName(_ id: UUID) -> String {
        tags.first { $0.id == id }?.name ?? ""
    }
}
