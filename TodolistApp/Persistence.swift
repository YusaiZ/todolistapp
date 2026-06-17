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

    /// 读取；文件不存在或解析失败时返回空数据。
    static func load() -> StoreData {
        guard FileManager.default.fileExists(atPath: dataURL.path),
              let raw = try? Data(contentsOf: dataURL),
              let decoded = try? JSONDecoder().decode(StoreData.self, from: raw)
        else {
            return StoreData(cards: [], tags: [])
        }
        return decoded
    }

    /// 写入；带缩进便于调试。
    @discardableResult
    static func save(_ data: StoreData) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let raw = try? encoder.encode(data) else { return false }
        do {
            try raw.write(to: dataURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
