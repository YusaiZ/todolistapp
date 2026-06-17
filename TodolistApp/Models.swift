import Foundation
import SwiftUI

/// 四种状态，对应看板的四列。
enum Status: String, Codable, CaseIterable {
    case plan, todo, doing, done

    /// 列标题（首字母大写）。
    var title: String {
        switch self {
        case .plan: return "Plan"
        case .todo: return "Todo"
        case .doing: return "Doing"
        case .done: return "Done"
        }
    }
}

/// 外观偏好。`.auto` 跟随系统，`.light` / `.dark` 强制。
/// 存进 UserDefaults（key = "appearance"），用 rawValue 编码。
enum AppearanceMode: String, CaseIterable {
    case auto, light, dark

    /// 菜单里显示的中文名。
    var label: String {
        switch self {
        case .auto: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    /// 切换按钮 / 菜单项的 SF Symbol。
    var icon: String {
        switch self {
        case .auto: return "macwindow"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// 传给 `.preferredColorScheme(_:)`；`.auto` 返回 nil = 跟随系统。
    var preferredScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 标签。name 在业务层按小写去重。
struct Tag: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    /// 调色板索引，用于 chip 配色。旧数据缺省时默认 0。
    var colorIndex: Int

    init(id: UUID = UUID(), name: String, colorIndex: Int = 0) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
    }

    // 兼容旧版本 JSON（无 colorIndex 字段）的解码兜底。
    enum CodingKeys: String, CodingKey { case id, name, colorIndex }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
    }
}

/// 10 色调色板（RGB），用于标签 chip。每个色相有两套配对：
/// 浅色模式 = 浅底 + 深字；深色模式 = 深底 + 亮字。两套都保证文字清晰。
enum TagPalette {
    struct Swatch {
        let bg: (Double, Double, Double)         // 浅色背景
        let fg: (Double, Double, Double)         // 浅色前景
        let darkBg: (Double, Double, Double)     // 深色背景
        let darkFg: (Double, Double, Double)     // 深色前景
    }

    static let swatches: [Swatch] = [
        // 蓝
        Swatch(bg: (0.95, 0.97, 1.00), fg: (0.20, 0.32, 0.60),
               darkBg: (0.13, 0.20, 0.36), darkFg: (0.74, 0.84, 1.00)),
        // 紫
        Swatch(bg: (0.96, 0.95, 1.00), fg: (0.40, 0.25, 0.62),
               darkBg: (0.22, 0.15, 0.36), darkFg: (0.80, 0.74, 1.00)),
        // 玫红
        Swatch(bg: (0.98, 0.95, 0.96), fg: (0.66, 0.22, 0.36),
               darkBg: (0.36, 0.14, 0.22), darkFg: (1.00, 0.74, 0.82)),
        // 橙
        Swatch(bg: (1.00, 0.95, 0.93), fg: (0.70, 0.34, 0.10),
               darkBg: (0.36, 0.20, 0.08), darkFg: (1.00, 0.78, 0.50)),
        // 金
        Swatch(bg: (1.00, 0.97, 0.90), fg: (0.62, 0.46, 0.04),
               darkBg: (0.34, 0.28, 0.06), darkFg: (1.00, 0.86, 0.52)),
        // 绿
        Swatch(bg: (0.95, 0.98, 0.93), fg: (0.20, 0.45, 0.16),
               darkBg: (0.12, 0.26, 0.12), darkFg: (0.74, 0.96, 0.70)),
        // 青
        Swatch(bg: (0.93, 0.98, 0.97), fg: (0.06, 0.42, 0.38),
               darkBg: (0.06, 0.24, 0.22), darkFg: (0.70, 0.96, 0.92)),
        // 蓝灰
        Swatch(bg: (0.95, 0.97, 0.99), fg: (0.18, 0.38, 0.52),
               darkBg: (0.12, 0.22, 0.30), darkFg: (0.78, 0.90, 1.00)),
        // 暖灰
        Swatch(bg: (0.98, 0.96, 0.94), fg: (0.45, 0.32, 0.18),
               darkBg: (0.26, 0.20, 0.14), darkFg: (0.94, 0.84, 0.70)),
        // 淡紫
        Swatch(bg: (0.97, 0.95, 0.98), fg: (0.42, 0.28, 0.58),
               darkBg: (0.24, 0.16, 0.34), darkFg: (0.86, 0.78, 1.00)),
    ]

    /// chip 背景色（自动随系统外观切换浅/深）。
    static func bg(_ index: Int) -> Color {
        let s = swatches[index % swatches.count]
        return Theme.dynamic(light: s.bg, dark: s.darkBg)
    }

    /// chip 前景文字色（自动随系统外观切换浅/深）。
    static func fg(_ index: Int) -> Color {
        let s = swatches[index % swatches.count]
        return Theme.dynamic(light: s.fg, dark: s.darkFg)
    }
}

/// 单个待办事件卡片。
struct Card: Identifiable, Codable {
    var id: UUID
    var content: String
    var tagIds: [UUID]
    var status: Status
    var order: Int          // 列内排序，升序
    var createdAt: Date

    init(id: UUID = UUID(),
         content: String,
         tagIds: [UUID] = [],
         status: Status = .plan,
         order: Int = 0,
         createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.tagIds = tagIds
        self.status = status
        self.order = order
        self.createdAt = createdAt
    }
}

/// 持久化到磁盘的整体结构。
struct StoreData: Codable {
    var cards: [Card]
    var tags: [Tag]
}
