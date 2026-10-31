import Foundation
import SwiftUI

// MARK: - 数据仓库（本机 JSON 持久化，不上传任何服务器）

final class Store: ObservableObject {

    static let shared = Store()

    @Published private(set) var state: AppState

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("MengBao", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("state.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppState.self, from: data) {
            state = decoded
        } else {
            state = AppState()
        }
        if state.currentID == nil {
            state.currentID = state.children.first?.id
        }
    }

    // MARK: 只读派生

    var current: Child? {
        guard let id = state.currentID else { return nil }
        return state.children.first { $0.id == id }
    }

    var settings: AppSettings { state.settings }

    // MARK: 写

    func update(_ block: (inout AppState) -> Void) {
        var copy = state
        block(&copy)
        state = copy
        persist()
    }

    func updateCurrent(_ block: (inout Child) -> Void) {
        guard let id = state.currentID else { return }
        var copy = state
        guard let idx = copy.children.firstIndex(where: { $0.id == id }) else { return }
        block(&copy.children[idx])
        state = copy
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("保存失败：\(error)")
        }
    }

    // MARK: 孩子

    @discardableResult
    func addChild(name: String, sex: Sex, birthDate: Date, avatar: String) -> UUID {
        let child = Child(name: name, sex: sex, birthDate: birthDate, avatar: avatar)
        update { s in
            s.children.append(child)
            s.currentID = child.id
        }
        return child.id
    }

    func selectChild(_ id: UUID) {
        update { $0.currentID = id }
    }

    func updateChild(_ child: Child) {
        update { s in
            if let idx = s.children.firstIndex(where: { $0.id == child.id }) {
                s.children[idx] = child
            }
        }
    }

    func deleteChild(_ id: UUID) {
        update { s in
            s.children.removeAll { $0.id == id }
            if s.currentID == id { s.currentID = s.children.first?.id }
        }
    }

    // MARK: 生长记录

    func addRecord(_ record: GrowthRecord) {
        updateCurrent { $0.records.append(record); $0.records.sort { $0.date < $1.date } }
    }

    func updateRecord(_ record: GrowthRecord) {
        updateCurrent { child in
            if let idx = child.records.firstIndex(where: { $0.id == record.id }) {
                child.records[idx] = record
            } else {
                child.records.append(record)
            }
            child.records.sort { $0.date < $1.date }
        }
    }

    func deleteRecord(_ id: UUID) {
        updateCurrent { $0.records.removeAll { $0.id == id } }
    }

    // MARK: 喂养

    func addFeed(_ log: FeedLog) {
        updateCurrent { $0.feeds.append(log) }
    }

    func deleteFeed(_ id: UUID) {
        updateCurrent { $0.feeds.removeAll { $0.id == id } }
    }

    // MARK: 尺码

    func addSize(_ record: SizeRecord) {
        updateCurrent { $0.sizes.append(record) }
    }

    func deleteSize(_ id: UUID) {
        updateCurrent { $0.sizes.removeAll { $0.id == id } }
    }

    // MARK: 接种

    func toggleShot(key: String) {
        updateCurrent { child in
            if child.shots[key] != nil {
                child.shots.removeValue(forKey: key)
            } else {
                child.shots[key] = ShotRecord(date: Date())
            }
        }
    }

    // MARK: 待办

    func addTodo(_ todo: TodoItem) {
        updateCurrent { $0.todos.append(todo) }
    }

    func toggleTodo(_ id: UUID) {
        updateCurrent { child in
            if let idx = child.todos.firstIndex(where: { $0.id == id }) {
                child.todos[idx].done.toggle()
            }
        }
    }

    func deleteTodo(_ id: UUID) {
        updateCurrent { $0.todos.removeAll { $0.id == id } }
    }

    // MARK: 设置

    func setWeightUnit(_ unit: String) { update { $0.settings.weightUnit = unit } }
    func setShowFeed(_ on: Bool) { update { $0.settings.showFeed = on } }
    func setShowShot(_ on: Bool) { update { $0.settings.showShot = on } }
    func setDarkMode(_ value: Bool?) { update { $0.settings.darkMode = value } }
    func setParents(father: Double?, mother: Double?) {
        update { $0.settings.fatherHeight = father; $0.settings.motherHeight = mother }
    }

    // MARK: 导入导出

    func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    func importJSON(_ text: String) throws {
        guard let data = text.data(using: .utf8) else { throw NSError(domain: "MengBao", code: 1, userInfo: [NSLocalizedDescriptionKey: "文件编码不正确"]) }
        let decoded = try JSONDecoder().decode(AppState.self, from: data)
        update { $0 = decoded }
        if state.currentID == nil { update { $0.currentID = $0.children.first?.id } }
    }

    func exportCSV(for child: Child) -> String {
        var lines = ["日期,年龄,身高cm,体重kg,BMI,身高百分位,体重百分位,脚长cm,头围cm,备注"]
        for r in child.sortedRecords {
            let e = GrowthMath.evaluate(child: child, record: r)
            let row = [
                GrowthMath.dateString(r.date),
                GrowthMath.ageText(from: child.birthDate, to: r.date),
                r.height.map { String(format: "%.1f", $0) } ?? "",
                r.weight.map { String(format: "%.1f", $0) } ?? "",
                e.bmi.map { String(format: "%.1f", $0) } ?? "",
                e.heightPercentile.map { String(format: "%.1f", $0) } ?? "",
                e.weightPercentile.map { String(format: "%.1f", $0) } ?? "",
                r.footLength.map { String(format: "%.1f", $0) } ?? "",
                r.headCirc.map { String(format: "%.1f", $0) } ?? "",
                r.note.replacingOccurrences(of: ",", with: "，")
            ]
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    func reset() {
        update { s in
            s.children = []
            s.currentID = nil
        }
    }

    // MARK: 示例数据

    func loadDemo() {
        let cal = Calendar.current
        func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: day)) ?? Date()
        }

        var sister = Child(name: "珊", sex: .girl, birthDate: d(2015, 10, 24), avatar: "👧")
        sister.records = [
            GrowthRecord(date: d(2025, 10, 24), height: 135.5, weight: 24.0, footLength: 24, headCirc: nil),
            GrowthRecord(date: d(2026, 4, 24), height: 135.8, weight: 24.2, footLength: 24, headCirc: nil),
            GrowthRecord(date: d(2026, 10, 24), height: 136.0, weight: 24.3, footLength: 24, headCirc: nil, note: "晨起空腹、脱鞋测量")
        ]
        sister.sizes = [SizeRecord(date: d(2026, 10, 24), footLength: 24, height: 136, note: "换季运动鞋，内长留 0.6cm")]
        let schedule = GrowthMath.schedule(for: sister).filter { $0.months <= 72 }
        for dose in schedule.dropLast() {
            sister.shots[dose.key] = ShotRecord(date: dose.dueDate)
        }
        sister.todos = [
            TodoItem(title: "预约 6 岁百白破加强针", due: nil, done: true),
            TodoItem(title: "每半年测一次身高体重", due: nil, done: false)
        ]

        var brother = Child(name: "弟弟", sex: .boy, birthDate: d(2026, 3, 15), avatar: "👦")
        brother.records = [
            GrowthRecord(date: d(2026, 5, 15), height: 65.5, weight: 7.2, footLength: 11.5, headCirc: nil),
            GrowthRecord(date: d(2026, 7, 15), height: 70.0, weight: 8.3, footLength: 11.5, headCirc: nil),
            GrowthRecord(date: d(2026, 9, 15), height: 72.2, weight: 9.2, footLength: 11.5, headCirc: nil)
        ]
        for i in 0..<3 {
            let day = cal.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            brother.feeds.append(FeedLog(date: day, kind: .sleep, minutes: 420 + i * 40))
            brother.feeds.append(FeedLog(date: day, kind: .bottle, ml: Double(180 + i * 20)))
            brother.feeds.append(FeedLog(date: day, kind: .breast, minutes: 15, side: i % 2 == 0 ? "左" : "右"))
            brother.feeds.append(FeedLog(date: day, kind: .diaper, diaperKind: "小便"))
        }
        brother.sizes = [SizeRecord(date: d(2026, 9, 15), footLength: 11.5, height: 72.2, note: "学步鞋 12 码")]

        update { s in
            s.children = [sister, brother]
            s.currentID = sister.id
            s.settings.fatherHeight = 175
            s.settings.motherHeight = 163
        }
    }
}
