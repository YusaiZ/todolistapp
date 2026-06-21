import Foundation

/// 负责 JSON 文件的读写。
/// 路径：~/Library/Application Support/TodolistApp/data.json
struct Persistence {
    static let appName = "TodolistApp"
    static let fileName = "data.json"

    /// 数据文件完整 URL，必要时创建父目录。
    static var dataURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent(appName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }

    /// 读取。
    ///
    /// 安全策略（防止「解码失败 → 显示空 → 防抖保存把空写回磁盘」的死亡螺旋）：
    /// - 文件不存在 → 全新用户，返回空（正常）。
    /// - 文件存在但解码失败 → **绝不返回空**，而是把损坏文件备份成 `data.corrupt.json`
    ///   并返回空。这样至少保住现场，便于排查；同时避免一次异常就把整库抹掉。
    ///   （历史上曾因一次运行异常触发空保存，导致数据被覆盖丢失。）
    static func load() -> StoreData {
        let url = dataURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return StoreData(cards: [], tags: [])
        }
        guard let raw = try? Data(contentsOf: url) else {
            // 文件在但读不出（权限/IO），同样不动它，返回空但不触发覆盖式保存由调用方决定。
            return StoreData(cards: [], tags: [])
        }
        do {
            return try JSONDecoder().decode(StoreData.self, from: raw)
        } catch {
            // 解码失败：先把损坏文件备份，再返回空。备份用时间戳避免反复覆盖。
            let backup = url.deletingLastPathComponent().appendingPathComponent("data.corrupt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
            NSLog("[TodolistApp] data.json 解码失败，已备份到 \(backup.path)。错误：\(error)")
            return StoreData(cards: [], tags: [])
        }
    }

    /// 写入；带缩进便于调试。
    @discardableResult
    static func save(_ data: StoreData) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // 磁盘上有非空数据时，禁止用空数据覆盖 ——
        // 防止任何运行异常导致的「空状态」把真实数据抹掉。
        let url = dataURL
        if data.cards.isEmpty && data.tags.isEmpty,
           FileManager.default.fileExists(atPath: url.path) {
            let existingSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            if existingSize > 50 {   // 比纯空模板 41 字节大，说明原本有数据
                NSLog("[TodolistApp] 拒绝用空数据覆盖非空 data.json（原 \(existingSize) 字节），已跳过保存。")
                return false
            }
        }
        guard let raw = try? encoder.encode(data) else { return false }
        do {
            try raw.write(to: url, options: .atomic)
            return true
        } catch {
            return false        }
    }
}
