import Foundation
import SwiftUI

// MARK: - iCloud 备份
//
// 侧载安装（爱思 / AltStore / TrollStore）拿不到 iCloud 容器权限，所以这里不用 entitlement：
// 用户通过「文件」选择器授权一个文件夹（建议选 iCloud 云盘里的「萌宝成长」），
// App 把安全书签存进 UserDefaults，之后就能自动往这个文件夹写备份、读备份。
// 换手机时在新手机上重装、选同一个 iCloud 文件夹，就能一键恢复。

struct BackupFile: Identifiable {
    let id: String          // 文件名
    let url: URL
    let date: Date
    let size: Int
    let childCount: Int
    let recordCount: Int
}

enum BackupError: LocalizedError {
    case noFolder
    case folderGone

    var errorDescription: String? {
        switch self {
        case .noFolder: return "还没有选择备份文件夹"
        case .folderGone: return "备份文件夹找不到了，请重新选择"
        }
    }
}

final class BackupManager: ObservableObject {

    static let shared = BackupManager()

    private let defaults = UserDefaults.standard
    private let fm = FileManager.default
    private let keyBookmark = "icloud_backup_bookmark"
    private let keyName = "icloud_backup_folder_name"
    private let keyLast = "icloud_backup_last_at"
    private let keyAuto = "icloud_backup_auto"
    /// 文件夹里最多保留多少份备份，超出的从最旧的删
    private let maxFiles = 20
    /// 自动备份最短间隔：改了数据也不会一直写盘
    private let autoInterval: TimeInterval = 5 * 60
    /// 改动后的防抖：连续输入只备份一次
    private let debounce: TimeInterval = 8

    @Published private(set) var folderName: String?
    @Published private(set) var lastBackupAt: Date?
    @Published var autoOn: Bool {
        didSet { defaults.set(autoOn, forKey: keyAuto) }
    }
    @Published var message: String?

    private var pending: DispatchWorkItem?
    private var dirty = false

    private init() {
        autoOn = defaults.object(forKey: keyAuto) as? Bool ?? true
        folderName = defaults.string(forKey: keyName)
        if let t = defaults.object(forKey: keyLast) as? TimeInterval, t > 0 {
            lastBackupAt = Date(timeIntervalSince1970: t)
        }
    }

    // MARK: 文件夹

    var hasFolder: Bool { resolvedFolder() != nil }

    func resolvedFolder() -> URL? {
        guard let data = defaults.data(forKey: keyBookmark) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withoutUI],
                                 relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(fresh, forKey: keyBookmark)
        }
        return url
    }

    func setFolder(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data: Data
        do {
            data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        defaults.set(data, forKey: keyBookmark)
        defaults.set(url.lastPathComponent, forKey: keyName)
        folderName = url.lastPathComponent
        message = "已连接到「\(url.lastPathComponent)」"
        AppLog.i("Backup", "备份文件夹已设置：\(url.lastPathComponent)")
    }

    func clearFolder() {
        defaults.removeObject(forKey: keyBookmark)
        defaults.removeObject(forKey: keyName)
        folderName = nil
    }

    private func withFolder<T>(_ body: (URL) throws -> T) throws -> T {
        guard let url = resolvedFolder() else { throw BackupError.noFolder }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            throw BackupError.folderGone
        }
        return try body(url)
    }

    // MARK: 备份

    static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f
    }()

    static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    @discardableResult
    func backupNow() -> Bool {
        do {
            let text = Store.shared.exportJSON()
            let name = "萌宝成长备份-\(Self.stampFormatter.string(from: Date())).json"
            let size = try withFolder { dir -> Int in
                let dest = dir.appendingPathComponent(name)
                guard let data = text.data(using: .utf8) else { throw BackupError.noFolder }
                try data.write(to: dest, options: .atomic)
                return data.count
            }
            lastBackupAt = Date()
            defaults.set(Date().timeIntervalSince1970, forKey: keyLast)
            dirty = false
            prune()
            message = "已备份（\(Self.sizeText(size))）"
            AppLog.i("Backup", "iCloud 备份成功：\(name)，\(size) 字节")
            return true
        } catch {
            message = "备份失败：\(error.localizedDescription)"
            AppLog.e("Backup", "备份失败：\(error)")
            return false
        }
    }

    private func prune() {
        guard let files = try? withFolder({ dir -> [URL] in
            let urls = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey],
                                                    options: [.skipsHiddenFiles])) ?? []
            return urls.filter { $0.pathExtension.lowercased() == "json" && $0.lastPathComponent.hasPrefix("萌宝成长备份-") }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        }) else { return }
        guard files.count > maxFiles else { return }
        for url in files.dropFirst(maxFiles) {
            try? withFolder { _ in try fm.removeItem(at: url) }
        }
    }

    // MARK: 列表 / 恢复

    func list() -> [BackupFile] {
        let files = (try? withFolder { dir -> [BackupFile] in
            let urls = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                                                    options: [.skipsHiddenFiles])) ?? []
            return urls
                .filter { $0.pathExtension.lowercased() == "json" && $0.lastPathComponent.hasPrefix("萌宝成长备份-") }
                .compactMap { url -> BackupFile? in
                    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                    let date = values?.contentModificationDate ?? Date.distantPast
                    let size = values?.fileSize ?? 0
                    let meta = Self.meta(of: url)
                    return BackupFile(id: url.lastPathComponent, url: url, date: date, size: size,
                                      childCount: meta.0, recordCount: meta.1)
                }
                .sorted { $0.date > $1.date }
        }) ?? []
        return files
    }

    private static func meta(of url: URL) -> (Int, Int) {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(AppState.self, from: data) else { return (0, 0) }
        let records = state.children.reduce(0) { sum, child in
            sum + child.records.count + child.feeds.count + child.sizes.count + child.todos.count
        }
        return (state.children.count, records)
    }

    func restore(_ file: BackupFile) throws {
        let text = try withFolder { _ in try String(contentsOf: file.url, encoding: .utf8) }
        try Store.shared.importJSON(text)
        message = "已恢复到 \(Self.displayFormatter.string(from: file.date)) 的备份"
        AppLog.i("Backup", "从 iCloud 备份恢复：\(file.id)")
    }

    func delete(_ file: BackupFile) {
        try? withFolder { _ in try fm.removeItem(at: file.url) }
    }

    // MARK: 自动备份

    /// Store 每次写数据都会调这里：有改动标记 dirty，按防抖 + 最短间隔自动备份
    func noteChange() {
        if Thread.isMainThread {
            handleChange()
        } else {
            DispatchQueue.main.async { [weak self] in self?.handleChange() }
        }
    }

    private func handleChange() {
        dirty = true
        guard autoOn else { return }
        // 先按最短间隔短路，避免每次输入都去解析书签
        if let last = lastBackupAt, Date().timeIntervalSince(last) < autoInterval { return }
        guard hasFolder else { return }
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.autoOn, self.hasFolder, self.dirty else { return }
            _ = self.backupNow()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    /// App 退到后台时调：把还没落盘的改动立刻备份掉（电话、锁屏都不会丢）
    func flush() {
        guard autoOn, hasFolder, dirty else { return }
        pending?.cancel()
        _ = backupNow()
    }

    // MARK: 文案

    static func sizeText(_ bytes: Int) -> String {
        if bytes >= 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / 1048576) }
        if bytes >= 1024 { return String(format: "%.0f KB", Double(bytes) / 1024) }
        return "\(bytes) B"
    }
}
