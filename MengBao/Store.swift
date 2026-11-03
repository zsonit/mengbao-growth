import Foundation
import SwiftUI

// MARK: - 数据仓库（本机 JSON 持久化，不上传任何服务器）

final class Store: ObservableObject {

    static let shared = Store()

    @Published private(set) var state: AppState
    /// 聊天 / 语音类页面独占全屏时，隐藏底部悬浮玻璃栏（避免遮住输入框和麦克风）
    @Published var tabBarHidden = false
    /// 按住说话进行中（录音 / 理解）：玻璃栏收起，页面遮罩才能全屏盖住
    @Published var voiceActive = false
    /// 正在按住录音（遮罩由 RootView 顶层渲染，不受首页按钮的 padding 影响）
    @Published var voiceHolding = false
    /// 松手后 AI 正在理解
    @Published var voiceProcessing = false
    /// 录音中的实时转写
    @Published var voiceLiveText = ""
    /// 遮罩被点一下（逃生口）：计数器 +1，由 HoldToTalkButton 监听后结束录音
    @Published var voiceStopTick = 0

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("MengBao", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("state.json")

        if let data = try? Data(contentsOf: fileURL) {
            do {
                state = try JSONDecoder().decode(AppState.self, from: data)
            } catch {
                AppLog.e("Store", "读取本机数据失败（可能数据文件损坏）：\(error)")
                state = AppState()
            }
        } else {
            state = AppState()
        }
        if state.currentID == nil {
            state.currentID = state.children.first?.id
        }
        // 启动时按当前数据重排一遍本机提醒（含之前排过、已完成的待办清理）
        refreshNotifications()
    }

    // MARK: 只读派生

    var current: Child? {
        guard let id = state.currentID else { return nil }
        return state.children.first { $0.id == id }
    }

    var settings: AppSettings { state.settings }

    // MARK: 写

    /// silent=true 由同步引擎回写数据用，不再触发新一轮同步，避免乒乓
    func update(_ block: (inout AppState) -> Void, silent: Bool = false) {
        var copy = state
        block(&copy)
        state = copy
        persist()
        refreshNotifications()
        if !silent { SyncManager.shared.onDataChanged() }
        BackupManager.shared.noteChange()
    }

    func updateCurrent(_ block: (inout Child) -> Void) {
        guard let id = state.currentID else { return }
        var copy = state
        guard let idx = copy.children.firstIndex(where: { $0.id == id }) else { return }
        block(&copy.children[idx])
        copy.children[idx].updatedAt = Date()
        state = copy
        persist()
        refreshNotifications()
        SyncManager.shared.onDataChanged()
        BackupManager.shared.noteChange()
    }

    /// 删除当前宝宝下的某条数据，同时写入删除墓碑（防止同步把条目并集合并回来）
    private func deleteInCurrent(_ tombstoneKey: String, _ block: (inout Child) -> Void) {
        update { s in
            s.tombstones.insert(tombstoneKey)
            guard let id = s.currentID, let idx = s.children.firstIndex(where: { $0.id == id }) else { return }
            block(&s.children[idx])
            s.children[idx].updatedAt = Date()
        }
    }

    /// 落盘放到串行后台队列：数据量大时编码 + 写盘不再卡主线程（录音、滚动时的卡顿来源之一）
    private let ioQueue = DispatchQueue(label: "mengbao.store.io", qos: .utility)

    private func persist() {
        let snapshot = state
        let url = fileURL
        ioQueue.async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                AppLog.e("Store", "保存数据失败：\(error)")
            }
        }
    }

    // MARK: 孩子

    @discardableResult
    func addChild(name: String, sex: Sex, birthDate: Date, avatar: String) -> UUID {
        var child = Child(name: name, sex: sex, birthDate: birthDate, avatar: avatar)
        child.updatedAt = Date()
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
                var c = child
                c.updatedAt = Date()
                s.children[idx] = c
            }
        }
    }

    func deleteChild(_ id: UUID) {
        update { s in
            s.tombstones.insert("child:\(id.uuidString)")
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
        deleteInCurrent("rec:\(id.uuidString)") { $0.records.removeAll { $0.id == id } }
    }

    // MARK: 喂养

    func addFeed(_ log: FeedLog) {
        updateCurrent { $0.feeds.append(log) }
    }

    func deleteFeed(_ id: UUID) {
        deleteInCurrent("feed:\(id.uuidString)") { $0.feeds.removeAll { $0.id == id } }
    }

    // MARK: 尺码

    /// 保存尺码：同一天已有记录时「更新那一条」而不是再追加一条
    func addSize(_ record: SizeRecord) {
        updateCurrent { child in
            if let same = child.sizes.filter({ $0.date == record.date }).max(by: { $0.filledCount < $1.filledCount }) {
                var merged = record.fillMissingFrom(same)
                merged.id = same.id            // 必须沿用原 id，否则对端会当成新记录，又变回两条
                child.sizes = child.sizes.map { $0.id == same.id ? merged : $0 }
            } else {
                child.sizes.append(record)
            }
            child.sizes.sort { $0.date < $1.date }
        }
    }

    func deleteSize(_ id: UUID) {
        deleteInCurrent("size:\(id.uuidString)") { $0.sizes.removeAll { $0.id == id } }
    }

    // MARK: 接种

    /// 保存自选（自费）疫苗勾选结果
    func setOptVaccines(_ ids: [String]) {
        updateCurrent { $0.optVaccines = ids.isEmpty ? nil : ids }
    }

    func toggleShot(key: String) {
        update { s in
            guard let id = s.currentID, let idx = s.children.firstIndex(where: { $0.id == id }) else { return }
            if s.children[idx].shots[key] != nil {
                s.children[idx].shots.removeValue(forKey: key)
                s.tombstones.insert("shot:\(key)")
            } else {
                s.children[idx].shots[key] = ShotRecord(date: Date())
                s.tombstones.remove("shot:\(key)")
            }
            s.children[idx].updatedAt = Date()
        }
    }

    // MARK: 待办

    func addTodo(_ todo: TodoItem) {
        updateCurrent { $0.todos.append(todo) }
    }

    /// 语音一次说好几条时批量加入：只触发一次保存 / 一次同步
    func addTodos(_ items: [TodoItem]) {
        guard !items.isEmpty else { return }
        updateCurrent { $0.todos.append(contentsOf: items) }
    }

    /// 换牙档案：标记 / 取消某颗乳牙的脱落
    func setToothFallen(_ code: Int, date: Date?) {
        updateCurrent { c in
            var map = c.teethFallen ?? [:]
            if let d = date { map[code] = d } else { map.removeValue(forKey: code) }
            c.teethFallen = map.isEmpty ? nil : map
        }
    }

    /// 换牙档案：记录 / 清除 / 修改某颗乳牙的龋齿（烂牙）
    func setToothDecay(_ code: Int, decay: ToothDecay?) {
        updateCurrent { c in
            var map = c.teethDecay ?? [:]
            if let d = decay { map[code] = d } else { map.removeValue(forKey: code) }
            c.teethDecay = map.isEmpty ? nil : map
        }
    }

    func toggleTodo(_ id: UUID) {
        updateCurrent { child in
            if let idx = child.todos.firstIndex(where: { $0.id == id }) {
                child.todos[idx].done.toggle()
            }
        }
    }

    func deleteTodo(_ id: UUID) {
        deleteInCurrent("todo:\(id.uuidString)") { $0.todos.removeAll { $0.id == id } }
    }

    // MARK: 设置

    func setWeightUnit(_ unit: String) { update { $0.settings.weightUnit = unit } }
    func setShowFeed(_ on: Bool) { update { $0.settings.showFeed = on } }
    func setShowSize(_ on: Bool) { update { $0.settings.showSize = on } }
    func setShowTrends(_ on: Bool) { update { $0.settings.showTrends = on } }
    func setShowLog(_ on: Bool) { update { $0.settings.showLog = on } }
    func setShowShot(_ on: Bool) { update { $0.settings.showShot = on } }
    func setDarkMode(_ value: Bool?) { update { $0.settings.darkMode = value } }
    func setParents(father: Double?, mother: Double?) {
        update { $0.settings.fatherHeight = father; $0.settings.motherHeight = mother }
    }

    // MARK: 提醒（本机通知）

    private var notifyWork: DispatchWorkItem?

    /// 数据一变就重排提醒；0.6 秒防抖，语音批量加待办只排一次
    func refreshNotifications() {
        notifyWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            NotificationManager.shared.reschedule(children: self.state.children,
                                                  settings: self.state.settings)
        }
        notifyWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    /// 定期测量提醒（间隔按天存：7 一周、14 两周、30 一个月、90 三个月）
    func setGrowthReminder(on: Bool, days: Int? = nil, hour: Int? = nil, minute: Int? = nil) {
        update { s in
            s.settings.growthReminderOn = on
            if let days = days { s.settings.growthReminderDays = max(1, days) }
            if let hour = hour { s.settings.growthReminderHour = hour }
            if let minute = minute { s.settings.growthReminderMinute = minute }
        }
    }

    func setTodoReminder(_ on: Bool) { update { $0.settings.todoReminderOn = on } }

    /// 本机静音/恢复某条待办的到期提醒（不随同步走：另一台手机不受影响，待办内容照样同步）
    func toggleTodoMute(_ id: UUID) {
        update { s in
            let key = id.uuidString
            if s.settings.mutedTodoReminders.contains(key) {
                s.settings.mutedTodoReminders.remove(key)
            } else {
                s.settings.mutedTodoReminders.insert(key)
            }
        }
    }

    var isTodoMuted: (UUID) -> Bool { { Store.shared.state.settings.mutedTodoReminders.contains($0.uuidString) } }

    /// 下次定期测量提醒的时间（首页 / 生长页展示用）
    func nextGrowthReminderDate(for child: Child) -> Date? {
        let s = settings
        guard s.growthReminderOn else { return nil }
        let cal = Calendar.current
        let base = child.records.map { $0.date }.max() ?? Date()
        var cursor = cal.startOfDay(for: base)
        var guardCount = 0
        while guardCount < 400 {
            guardCount += 1
            guard let day = cal.date(byAdding: .day, value: max(1, s.growthReminderDays), to: cursor) else { return nil }
            cursor = day
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = s.growthReminderHour
            comps.minute = s.growthReminderMinute
            if let fire = cal.date(from: comps), fire > Date() { return fire }
        }
        return nil
    }

    // MARK: 快捷入口

    var quickEntries: [QuickEntry] { state.settings.resolvedQuickEntries }

    /// 首页要展示的入口（过滤掉喂养类，若喂养模块关闭）
    var homeQuickEntries: [QuickEntry] {
        let feedKinds: Set<String> = ["bottle", "breast", "pumping", "solid", "supplement"]
        return quickEntries.filter { $0.visible && (settings.showFeed || !feedKinds.contains($0.kind)) }
    }

    func setQuickEntries(_ entries: [QuickEntry]) {
        update { $0.settings.quickEntries = entries }
    }

    func moveQuickEntry(from source: IndexSet, to destination: Int) {
        var list = quickEntries
        list.move(fromOffsets: source, toOffset: destination)
        setQuickEntries(list)
    }

    func toggleQuickEntry(_ id: String) {
        var list = quickEntries
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        list[idx].visible.toggle()
        setQuickEntries(list)
    }

    func addCustomQuickEntry(title: String, icon: String) {
        var list = quickEntries
        let id = "custom-\(UUID().uuidString)"
        list.append(QuickEntry(id: id, kind: "custom", title: title, icon: icon, visible: true))
        setQuickEntries(list)
    }

    func deleteQuickEntry(_ id: String) {
        setQuickEntries(quickEntries.filter { $0.id != id })
    }

    func resetQuickEntries() {
        update { $0.settings.quickEntries = [] }
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
        NotificationManager.shared.cancelAll()
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
