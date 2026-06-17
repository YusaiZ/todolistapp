import AppKit
import Foundation

// 一次性工具：绘制 1024×1024 的 app logo PNG。
// 用法：make_icon <输出路径>
// 设计：白色圆角底 + 四列抽象看板（黑白灰，第3列纯黑强调），呼应 app 视觉。
@main
struct MakeIcon {
    static func main() {
        let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
        guard let pngData = render() else {
            fputs("生成图像失败\n", stderr); exit(1)
        }
        let url = URL(fileURLWithPath: outPath)
        do {
            try pngData.write(to: url)
            print("已生成: \(url.path)")
        } catch {
            fputs("写入 PNG 失败: \(error)\n", stderr); exit(1)
        }
    }

    static func render() -> Data? {
        let size = 1024
        guard let ctx = CGContext(data: nil,
                                  width: size, height: size,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }

        // macOS 默认 app icon 是 squircle（超椭圆圆角矩形）。
        // 这里用圆角矩形近似：先画白底圆角矩形，整张图最后再 mask 成圆角。
        let corner: CGFloat = 225   // ≈ 1024 * 22%，接近系统 squircle 圆角
        let iconRect = CGRect(x: 0, y: 0, width: size, height: size)

        // 把绘制裁剪到圆角矩形内，确保白底和内容都不溢出圆角。
        ctx.saveGState()
        let clipPath = CGPath(roundedRect: iconRect,
                              cornerWidth: corner, cornerHeight: corner, transform: nil)
        ctx.addPath(clipPath)
        ctx.clip()

        // 不透明白底（macOS icon 规范要求背景不透明）。
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(iconRect)

        // margin 控制 icon 内容占比：240 时图形约占 icon 53%，四周留白接近系统 app icon。
        let margin: CGFloat = 240
        let boardRect = CGRect(x: margin, y: margin,
                               width: CGFloat(size) - margin * 2,
                               height: CGFloat(size) - margin * 2)
        let colCount = 4
        let gap: CGFloat = 30
        let colWidth = (boardRect.width - gap * CGFloat(colCount - 1)) / CGFloat(colCount)

        // 四列高度递增，模拟 plan→todo→doing→done 的进度感。
        let heights: [CGFloat] = [0.40, 0.55, 0.72, 0.92]
        // 第 3 列(Doing)用纯黑做强调，其余灰，保持黑白系。
        let fills: [(CGFloat, CGFloat, CGFloat)] = [
            (0.80, 0.80, 0.80),
            (0.62, 0.62, 0.62),
            (0.08, 0.08, 0.08),
            (0.42, 0.42, 0.42),
        ]

        for i in 0..<colCount {
            let h = boardRect.height * heights[i]
            let x = boardRect.minX + CGFloat(i) * (colWidth + gap)
            let rect = CGRect(x: x, y: boardRect.minY, width: colWidth, height: h)
            let path = CGPath(roundedRect: rect, cornerWidth: 28, cornerHeight: 28, transform: nil)
            ctx.addPath(path)
            let c = fills[i]
            ctx.setFillColor(CGColor(red: c.0, green: c.1, blue: c.2, alpha: 1))
            ctx.fillPath()
        }
        ctx.restoreGState()   // 解除圆角裁剪

        guard let img = ctx.makeImage() else { return nil }
        // 在内存里产出 PNG data。
        let mut = NSMutableData()
        guard let d = CGImageDestinationCreateWithData(mut as CFMutableData,
                                                       "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(d, img, nil)
        guard CGImageDestinationFinalize(d) else { return nil }
        return mut as Data
    }
}
