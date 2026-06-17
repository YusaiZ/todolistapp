import SwiftUI
import AppKit

/// 主题层：一组随系统外观自动切换的语义颜色 token。
///
/// 这套 app 的视觉语言是「黑白色系」（见 README）。深色模式不是套系统蓝，
/// 而是把写死的 `Color.white` / `Color.black` 反相成中性灰阶，保持原来的克制感。
/// 所有 token 都用 `NSColor(name:dynamicProvider:)` 包装，浅/深色自动响应。
enum Theme {
    /// 用浅/深两套 NSColor 构造一个会跟随系统外观切换的 SwiftUI Color。
    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        let ns = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil
                ? dark
                : light
        }
        return Color(ns)
    }

    /// RGB 元组重载：方便调色板（TagPalette）这类按元组存色的地方直接生成动态色。
    static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        dynamic(
            light: NSColor(srgbRed: light.0, green: light.1, blue: light.2, alpha: 1),
            dark: NSColor(srgbRed: dark.0, green: dark.1, blue: dark.2, alpha: 1)
        )
    }

    // MARK: - 背景层级

    /// app 主背景 / 顶栏背景（纯白 ↔ 近黑）。
    static let appBackground = dynamic(
        light: NSColor(white: 1.0, alpha: 1),
        dark: NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)   // #1C1C1E
    )

    /// 卡片表面（白 ↔ 略亮的深灰，让卡片在深色背景上浮起来）。
    static let cardSurface = dynamic(
        light: NSColor(white: 1.0, alpha: 1),
        dark: NSColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1)   // #2C2C2E
    )

    /// 看板列底色（浅灰 4% ↔ 白 6%）。
    static let columnFill = dynamic(
        light: NSColor(white: 0.0, alpha: 0.04),
        dark: NSColor(white: 1.0, alpha: 0.06)
    )

    // MARK: - 控件 / 描边

    /// 计数徽章、已选标签 chip 的底色（黑 8% ↔ 白 12%）。
    static let badgeFill = dynamic(
        light: NSColor(white: 0.0, alpha: 0.08),
        dark: NSColor(white: 1.0, alpha: 0.12)
    )

    /// 选中标签行的底色（黑 6% ↔ 白 10%）。
    static let selectedRowFill = dynamic(
        light: NSColor(white: 0.0, alpha: 0.06),
        dark: NSColor(white: 1.0, alpha: 0.10)
    )

    /// 极细描边 / hairline（黑 6% ↔ 白 10%）。
    static let hairline = dynamic(
        light: NSColor(white: 0.0, alpha: 0.06),
        dark: NSColor(white: 1.0, alpha: 0.10)
    )

    /// 输入框 / 建议浮层描边（黑 12% ↔ 白 16%）。
    static let inputBorder = dynamic(
        light: NSColor(white: 0.0, alpha: 0.12),
        dark: NSColor(white: 1.0, alpha: 0.16)
    )

    // MARK: - 强调

    /// 「新建」按钮这类实心强调按钮的底色（黑 ↔ 白）。文字应配反色。
    static let accentButtonBg = dynamic(
        light: NSColor(white: 0.0, alpha: 1),
        dark: NSColor(white: 1.0, alpha: 1)
    )

    /// 强调按钮上的文字色（白 ↔ 黑），始终与 `accentButtonBg` 反相。
    static let accentButtonText = dynamic(
        light: NSColor(white: 1.0, alpha: 1),
        dark: NSColor(white: 0.0, alpha: 1)
    )

    /// 次级强调文字（如已选 chip 上的名字，浅色用 0.25 深灰，深色用 0.75 亮灰）。
    static let secondaryEmphasis = dynamic(
        light: NSColor(white: 0.25, alpha: 1),
        dark: NSColor(white: 0.75, alpha: 1)
    )

    /// 卡片弥散投影色（带极淡冷蓝的灰）。深色下整体压暗、透明度降低，保持柔和。
    static let cardShadow = dynamic(
        light: NSColor(red: 0.40, green: 0.46, blue: 0.58, alpha: 1),
        dark: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
    )
}

/// 便捷扩展：让语义 token 像 `Color.white` 一样直接写 `.appBackground`。
extension Color {
    static var appBackground: Color { Theme.appBackground }
    static var cardSurface: Color { Theme.cardSurface }
    static var columnFill: Color { Theme.columnFill }
    static var badgeFill: Color { Theme.badgeFill }
    static var selectedRowFill: Color { Theme.selectedRowFill }
    static var hairline: Color { Theme.hairline }
    static var inputBorder: Color { Theme.inputBorder }
    static var accentButtonBg: Color { Theme.accentButtonBg }
    static var accentButtonText: Color { Theme.accentButtonText }
    static var secondaryEmphasis: Color { Theme.secondaryEmphasis }
    static var cardShadow: Color { Theme.cardShadow }
}
