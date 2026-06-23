import Foundation

/// 负责 JSON 文件的读写。
/// 路径：~/Library/Application Support/TodolistApp/data.json
///
/// 数据安全（防止「内存突然变空 → 保存 → 覆盖真实数据」的死亡螺旋）：
/// 1. load() 解码失败：备份损坏文件为 data.corrupt.json，绝不静默返空。
/// 2. save() 写入前：先把磁盘当前文件备份为 data.bak.json（保留上一版可恢复）。
/// 3. save() 拒绝「内存全空 + 历史曾有数据」的保存：用 highWaterMark（只增不减）
///    记住历史最大卡数；同时检查磁盘 data.bak.json 的实际卡数，双信号防清空。
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
            try? fm.createDirectory(atPath: dir.path, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }

    private static var backupURL: URL {
        dataURL.deletingLastPathComponent().appendingPathComponent("data.bak.json")
    }
    private static var corruptURL: URL {
        dataURL.deletingLastPathComponent().appendingPathComponent("data.corrupt.json")
    }

    /// 历史最大卡片数（高水位线，只增不减）。
    /// 关键：不因某次加载到空数据而清零 —— 否则死亡螺旋里它会被一起污染。
    private static let highWaterMarkKey = "persistence.highWaterMark"
    private static var highWaterMark: Int {
        get { UserDefaults.standard.integer(forKey: highWaterMarkKey) }
        set {
            // 只允许往大写，绝不回退。
            if newValue > UserDefaults.standard.integer(forKey: highWaterMarkKey) {
                UserDefaults.standard.set(newValue, forKey: highWaterMarkKey)
            }
        }
    }

    /// 数某个 JSON 文件里有多少张卡（用于独立检查，避免污染主状态）。
    private static func cardCount(in url: URL) -> Int {
        guard let raw = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(StoreData.self, from: raw) else { return 0 }
        return decoded.cards.count
    }

    /// 读取。
    static func load() -> StoreData {
        let url = dataURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return StoreData(cards: [], tags: [])
        }
        guard let raw = try? Data(contentsOf: url) else {
            return StoreData(cards: [], tags: [])
        }
        do {
            let decoded = try JSONDecoder().decode(StoreData.self, from: raw)
            // 高水位线只在有数据时抬升；加载到空绝不降低它。
            if decoded.cards.count > 0 {
                highWaterMark = decoded.cards.count
            }
            return decoded
        } catch {
            let backup = corruptURL
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
            NSLog("[TodolistApp] data.json 解码失败，已备份到 \(backup.path)。错误：\(error)")
            return StoreData(cards: [], tags: [])
        }
    }

    /// 写入；带缩进便于调试。
    @discardableResult
    static func save(_ data: StoreData) -> Bool {
        let url = dataURL

        // 防清空核心检查：内存全空，但「历史高水位 > 0」或「备份文件里有卡」→ 拒绝写入。
        // 双信号：highWaterMark 防"刚录完就崩"，data.bak.json 防"高水位被早期清零"。
        if data.cards.isEmpty && data.tags.isEmpty {
            let historicalMax = highWaterMark
            let backupCount = cardCount(in: backupURL)
            if historicalMax > 0 || backupCount > 0 {
                NSLog("[TodolistApp] 拒绝保存：内存为空但历史高水位=\(historicalMax)、备份卡数=\(backupCount)，疑似异常，已跳过。")
                return false
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let raw = try? encoder.encode(data) else { return false }

        // 写入前备份当前文件（保留上一版，可恢复）。
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: url, to: backupURL)
        }

        do {
            try raw.write(to: url, options: .atomic)
            if data.cards.count > 0 {
                highWaterMark = data.cards.count
            }
            return true
        } catch {
            return false
        }
    }

    /// 从备份恢复（data.bak.json → data.json）。供"数据丢失后手动恢复"用。
    @discardableResult
    static func restoreFromBackup() -> Bool {
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return false }
        do {
            if FileManager.default.fileExists(atPath: dataURL.path) {
                try? FileManager.default.removeItem(at: dataURL)
            }
            try FileManager.default.copyItem(at: backupURL, to: dataURL)
            // 恢复后同步抬升高水位，避免下一次 save 又因为"空内存"被拒。
            let restored = cardCount(in: dataURL)
            if restored > 0 { highWaterMark = restored }
            return true
        } catch {
            NSLog("[TodolistApp] 从备份恢复失败：\(error)")
            return false
        }
    }
}
