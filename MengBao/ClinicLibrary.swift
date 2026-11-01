import Foundation
import Combine

/// 门诊库：优先使用「同步库」（从高德抓取的全省接种单位），没有同步过则用内置样例库。
final class ClinicLibrary: ObservableObject {

    static let shared = ClinicLibrary()

    @Published private(set) var synced: [Clinic] = []
    @Published private(set) var updatedAt: Date?

    private struct Payload: Codable {
        var updatedAt: Date
        var clinics: [Clinic]
    }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("mengbao_clinics.json")
    }()

    private init() {
        load()
    }

    /// 当前生效的门诊库
    var all: [Clinic] {
        synced.isEmpty ? Standards.clinics : synced
    }

    var isSynced: Bool { !synced.isEmpty }

    var summary: String {
        if synced.isEmpty {
            return "内置示例 \(Standards.clinics.count) 家 · 未同步全省数据"
        }
        let cityCount = Set(synced.map { $0.city }).count
        return "已同步 \(synced.count) 家 · 覆盖 \(cityCount) 个城市"
    }

    var updatedText: String {
        guard let updatedAt = updatedAt else { return "从未同步" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return "更新于 " + formatter.string(from: updatedAt)
    }

    /// 实际存在的城市（按门诊数量排序）
    func cities() -> [String] {
        let counts = Dictionary(grouping: all, by: { $0.city }).mapValues { $0.count }
        return counts.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
        }.map { $0.key }
    }

    // MARK: 持久化

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return }
        synced = payload.clinics
        updatedAt = payload.updatedAt
    }

    func replace(with clinics: [Clinic]) {
        synced = clinics
        updatedAt = Date()
        persist()
    }

    func clear() {
        synced = []
        updatedAt = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func persist() {
        let payload = Payload(updatedAt: updatedAt ?? Date(), clinics: synced)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
