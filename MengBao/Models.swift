import Foundation

// MARK: - 性别

enum Sex: String, Codable, CaseIterable, Identifiable {
    case boy = "男"
    case girl = "女"

    var id: String { rawValue }
    var symbol: String { self == .boy ? "👦" : "👧" }
    var label: String { rawValue }
}

// MARK: - 生长记录

struct GrowthRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var height: Double?
    var weight: Double?
    var footLength: Double?
    var headCirc: Double?
    var note: String = ""

    var hasAnyValue: Bool {
        height != nil || weight != nil || footLength != nil || headCirc != nil
    }
}

// MARK: - 喂养记录

struct FeedLog: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case sleep, breast, bottle, pumping, storage, diaper, solid, supplement, medicine, temp, notebook, custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .sleep: return "睡眠"
            case .breast: return "亲喂"
            case .bottle: return "瓶喂"
            case .pumping: return "吸奶"
            case .storage: return "储奶"
            case .diaper: return "尿布"
            case .solid: return "辅食"
            case .supplement: return "补剂"
            case .medicine: return "喂药"
            case .temp: return "体温"
            case .notebook: return "记事本"
            case .custom: return "记录"
            }
        }

        var icon: String {
            switch self {
            case .sleep: return "😴"
            case .breast: return "🤱"
            case .bottle: return "🍼"
            case .pumping: return "🧴"
            case .storage: return "🥛"
            case .diaper: return "🧷"
            case .solid: return "🍚"
            case .supplement: return "💊"
            case .medicine: return "🩺"
            case .temp: return "🌡️"
            case .notebook: return "📒"
            case .custom: return "📝"
            }
        }

        var unit: String {
            switch self {
            case .sleep, .breast, .pumping: return "分钟"
            case .bottle, .storage, .medicine: return "ml"
            case .diaper: return "次"
            case .solid: return ""
            case .supplement: return ""
            case .temp: return "℃"
            case .notebook: return ""
            case .custom: return ""
            }
        }

        /// 首页「今日记录」三张统计卡用得到的口径
        var isFeedLike: Bool {
            switch self {
            case .bottle, .breast, .pumping, .solid, .sleep, .diaper: return true
            default: return false
            }
        }
    }

    var id = UUID()
    var date: Date
    var kind: Kind
    var minutes: Int?
    var ml: Double?
    var side: String?
    var diaperKind: String?
    /// 通用数值位：体温（℃）、辅食克数、喂药剂量（ml）等
    var value: Double?
    /// 通用标签位：瓶喂（奶粉/人奶）、储奶（冷藏/冷冻）、喂药/记事本（发烧/感冒…）
    var tag: String?
    var note: String = ""

    var summary: String {
        switch kind {
        case .sleep: return "\(minutes ?? 0) 分钟"
        case .breast: return "\((side ?? "左")) \(minutes.map { "\($0) 分钟" } ?? "")"
        case .bottle:
            let base = "\(Int(ml ?? 0)) ml"
            return tag.map { "\(base) · \($0)" } ?? base
        case .pumping: return "\(Int(ml ?? 0)) ml"
        case .storage:
            let base = "\(Int(ml ?? 0)) ml"
            return tag.map { "\(base) · \($0)" } ?? base
        case .diaper: return diaperKind ?? "小便"
        case .solid: return note.isEmpty ? "已添加辅食" : note
        case .supplement: return note.isEmpty ? "已服用" : note
        case .medicine:
            let dose = (value ?? 0) > 0 ? String(format: "%.1f ml", value ?? 0) : ""
            let name = note.isEmpty ? "喂药" : note
            let body = dose.isEmpty ? name : "\(name) \(dose)"
            return tag.map { "\(body) · \($0)" } ?? body
        case .temp: return String(format: "%.1f ℃", value ?? 36.5)
        case .notebook: return note.isEmpty ? "记事本" : note
        case .custom: return note.isEmpty ? "记录" : note
        }
    }

    /// 语音/一键录入时给 AI 卡用的自然语言摘要
    var speakText: String {
        switch kind {
        case .sleep: return "睡了 \(minutes ?? 0) 分钟"
        case .breast: return "亲喂 \(side ?? "左") 侧 \(minutes ?? 0) 分钟"
        case .bottle:
            let base = "喝了 \(Int(ml ?? 0)) 毫升\(tag ?? "奶")"
            return base
        case .pumping: return "吸奶 \(Int(ml ?? 0)) 毫升"
        case .storage:
            let base = "储奶 \(Int(ml ?? 0)) 毫升"
            return tag.map { "\(base)（\($0)）" } ?? base
        case .diaper: return diaperKind ?? "小便"
        case .solid: return "吃了 \(note)"
        case .supplement: return "补了 \(note)"
        case .medicine:
            let dose = (value ?? 0) > 0 ? String(format: "%.1f 毫升", value ?? 0) : ""
            let body = dose.isEmpty ? "喂了 \(note)" : "喂了 \(note) \(dose)"
            return tag.map { "\(body)（\($0)）" } ?? body
        case .temp: return String(format: "体温 %.1f 度", value ?? 36.5)
        case .notebook: return "记录：\(note)"
        case .custom: return note
        }
    }
}

// MARK: - 鞋服尺码

struct SizeRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var footLength: Double?
    var height: Double?
    // 身体围度 / 衣物尺寸（cm）
    var shoulder: Double?      // 肩宽
    var waist: Double?         // 腰围
    var hip: Double?           // 臀围
    var thigh: Double?         // 大腿围
    var calf: Double?          // 小腿围
    var legLength: Double?     // 腿长
    var armLength: Double?     // 手臂长
    var topLength: Double?     // 衣长
    var sleeve: Double?        // 袖长
    var pantsLength: Double?   // 裤长
    var shoeSize: Int?         // 穿鞋码数（中国码）
    var shoeInner: Double?     // 鞋内长
    var note: String = ""

    /// 填了几项（含备注）：用来挑「最完整」的那条，也是去重时的优先级
    var filledCount: Int {
        let values: [Double?] = [footLength, height, shoulder, waist, hip, thigh, calf,
                                 legLength, armLength, topLength, sleeve, pantsLength, shoeInner,
                                 shoeSize.map { Double($0) }]
        return values.compactMap { $0 }.count + (note.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
    }

    /// 全是空的记录（历史脏数据），展示和同步时都过滤掉
    var hasContent: Bool { filledCount > 0 }

    /// 同一天归并用的键（同步时同一天只保留一条去重记录）
    var dayKey: String { String(Int(date.timeIntervalSinceReferenceDate / 86400)) }

    /// 用旧记录补上新记录里没填的项（同一天再保存时，不会把上次填的围度弄丢）
    func fillMissingFrom(_ old: SizeRecord) -> SizeRecord {
        var out = self
        out.footLength = footLength ?? old.footLength
        out.height = height ?? old.height
        out.shoulder = shoulder ?? old.shoulder
        out.waist = waist ?? old.waist
        out.hip = hip ?? old.hip
        out.thigh = thigh ?? old.thigh
        out.calf = calf ?? old.calf
        out.legLength = legLength ?? old.legLength
        out.armLength = armLength ?? old.armLength
        out.topLength = topLength ?? old.topLength
        out.sleeve = sleeve ?? old.sleeve
        out.pantsLength = pantsLength ?? old.pantsLength
        out.shoeSize = shoeSize ?? old.shoeSize
        out.shoeInner = shoeInner ?? old.shoeInner
        if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.note = old.note }
        return out
    }
}

// MARK: - 待办

struct TodoItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var due: Date?
    var done: Bool = false
}

// MARK: - 接种记录

struct ShotRecord: Codable, Hashable {
    var date: Date
    var note: String = ""
}

// MARK: - 龋齿（换牙档案）

/// 一颗乳牙的龋齿（烂牙）记录
struct ToothDecay: Codable, Hashable {
    var date: Date              // 发现 / 就诊日期
    var severity: Int = 1       // 1=轻度（白斑、浅龋）2=中度（有洞）3=重度（深龋、疼过、需治疗）
    var note: String = ""       // 备注：哪一面、医生说了什么、是否已补

    var severityLabel: String {
        switch severity {
        case 3: return "重度"
        case 2: return "中度"
        default: return "轻度"
        }
    }

    /// 中重度建议尽快看牙医
    var needsVisit: Bool { severity >= 2 }
}

// MARK: - 宝宝

struct Child: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var sex: Sex
    var birthDate: Date
    var avatar: String = ""
    var avatarPath: String?          // 自定义照片（相对 Documents 的路径，如 avatars/<id>.jpg）
    var createdAt = Date()

    var records: [GrowthRecord] = []
    var feeds: [FeedLog] = []
    var sizes: [SizeRecord] = []
    var shots: [String: ShotRecord] = [:]
    var todos: [TodoItem] = []
    var teethFallen: [Int: Date]? = nil   // 换牙档案：乳牙 FDI 编码 -> 脱落日期
    var teethDecay: [Int: ToothDecay]? = nil  // 换牙档案：乳牙 FDI 编码 -> 龋齿（烂牙）记录
    var optVaccines: [String]? = nil      // 自选（自费）疫苗 id，见 Standards.optionalCatalog
    var updatedAt: Date? = nil            // 配对同步：档案最后一次修改时刻（冲突时后改的赢）
    var birthdayRemind: Bool? = nil       // 旧字段：生日提醒总开关（兼容旧版本数据，nil = 开）
    var birthdayTime: Int? = nil          // 旧字段：生日提醒时刻（0-1439 分钟，nil = 9:00）
    // v2.10.22：生日提醒拆分为「当天」和「提前」两个独立开关，时间各自可调
    var bdaySameDayOn: Bool? = nil        // 当天提醒开关（nil = 跟随旧字段，默认开）
    var bdaySameDayTime: Int? = nil       // 当天提醒时刻（分钟，nil = 跟随 birthdayTime / 9:00）
    var bdayAdvanceOn: Bool? = nil        // 提前提醒开关（nil = 跟随旧字段，默认开）
    var bdayAdvanceDays: Int? = nil       // 提前几天（默认 1）
    var bdayAdvanceTime: Int? = nil       // 提前提醒时刻（分钟，nil = 跟随 birthdayTime / 9:00）

    /// 当天提醒是否开启（兼容旧数据：未拆分时跟随总开关）
    var bdaySameDayEnabled: Bool { bdaySameDayOn ?? birthdayRemind ?? true }
    /// 提前提醒是否开启（兼容旧数据：未拆分时跟随总开关）
    var bdayAdvanceEnabled: Bool { bdayAdvanceOn ?? birthdayRemind ?? true }
    /// 当天提醒时刻（分钟）
    var bdaySameDayMinutes: Int { bdaySameDayTime ?? birthdayTime ?? 9 * 60 }
    /// 提前提醒时刻（分钟）
    var bdayAdvanceMinutes: Int { bdayAdvanceTime ?? birthdayTime ?? 9 * 60 }
    /// 提前几天（至少 1 天）
    var bdayAdvanceDaysEffective: Int { max(1, bdayAdvanceDays ?? 1) }


    var displayAvatar: String {
        avatar.isEmpty ? (sex == .girl ? "👧" : "👦") : avatar
    }

    var sortedRecords: [GrowthRecord] {
        records.sorted { $0.date < $1.date }
    }

    var latestRecord: GrowthRecord? {
        records.max { $0.date < $1.date }
    }

    var latestHeight: Double? {
        sortedRecords.last(where: { $0.height != nil })?.height
    }

    var latestWeight: Double? {
        sortedRecords.last(where: { $0.weight != nil })?.weight
    }
}

// MARK: - 快捷入口配置

struct QuickEntry: Identifiable, Codable, Hashable {
    var id: String                  // 内置项用 kind 值，自定义项用 "custom-<UUID>"
    var kind: String                // bottle/breast/... 或 height/weight/head/custom
    var title: String
    var icon: String
    var visible: Bool = true

    var isBuiltin: Bool { !id.hasPrefix("custom-") }

    /// 内置入口默认表（顺序即首页横滑顺序）
    static let builtins: [QuickEntry] = [
        QuickEntry(id: "bottle", kind: "bottle", title: "瓶喂", icon: "🍼"),
        QuickEntry(id: "breast", kind: "breast", title: "亲喂", icon: "🤱"),
        QuickEntry(id: "pumping", kind: "pumping", title: "吸奶", icon: "🧴"),
        QuickEntry(id: "storage", kind: "storage", title: "储奶", icon: "🥛"),
        QuickEntry(id: "sleep", kind: "sleep", title: "睡眠", icon: "😴"),
        QuickEntry(id: "diaper", kind: "diaper", title: "尿布", icon: "🧷"),
        QuickEntry(id: "solid", kind: "solid", title: "辅食", icon: "🍚"),
        QuickEntry(id: "supplement", kind: "supplement", title: "补剂", icon: "💊"),
        QuickEntry(id: "medicine", kind: "medicine", title: "喂药", icon: "🩺"),
        QuickEntry(id: "temp", kind: "temp", title: "体温", icon: "🌡️"),
        QuickEntry(id: "notebook", kind: "notebook", title: "记事本", icon: "📒"),
        QuickEntry(id: "weight", kind: "weight", title: "体重", icon: "⚖️"),
        QuickEntry(id: "height", kind: "height", title: "身高", icon: "📏"),
        QuickEntry(id: "head", kind: "head", title: "头围", icon: "🧢")
    ]
}

// MARK: - 设置

struct AppSettings: Codable, Hashable {
    var weightUnit: String = "kg"          // kg / 斤
    var showFeed: Bool = true
    var showShot: Bool = true
    var showSize: Bool = true              // 鞋服尺码模块
    var showTrends: Bool = true            // 成长趋势模块
    var showLog: Bool? = nil               // 运行日志（独立开关；可选类型保证旧数据可解码）
    var darkMode: Bool? = nil              // nil = 跟随系统
    var fatherHeight: Double? = nil
    var motherHeight: Double? = nil
    /// 空数组 = 用内置默认顺序；用户改过之后写入完整列表
    var quickEntries: [QuickEntry] = []

    // MARK: 提醒（本机通知）
    var growthReminderOn: Bool = false       // 定期测量提醒开关
    var growthReminderDays: Int = 30         // 间隔天数：7 = 一周、30 = 一个月、90 = 三个月
    var growthReminderHour: Int = 9          // 提醒时间（时）
    var growthReminderMinute: Int = 0        // 提醒时间（分）
    var todoReminderOn: Bool = true          // 待办到期提醒开关
    /// 本机静音的待办 id（不随同步走：每台手机各自决定哪些待办不响，内容照样同步）
    var mutedTodoReminders: Set<String> = []

    // 宽松解码：老版本备份缺哪个字段都用默认值兜底，避免升级/恢复备份时整份数据解不出来
    init(weightUnit: String = "kg", showFeed: Bool = true, showShot: Bool = true,
         showSize: Bool = true, showTrends: Bool = true, darkMode: Bool? = nil, fatherHeight: Double? = nil,
         motherHeight: Double? = nil, quickEntries: [QuickEntry] = [], showLog: Bool? = nil) {
        self.weightUnit = weightUnit
        self.showFeed = showFeed
        self.showShot = showShot
        self.showSize = showSize
        self.showTrends = showTrends
        self.darkMode = darkMode
        self.fatherHeight = fatherHeight
        self.motherHeight = motherHeight
        self.quickEntries = quickEntries
        self.showLog = showLog
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weightUnit = try c.decodeIfPresent(String.self, forKey: .weightUnit) ?? "kg"
        showFeed = try c.decodeIfPresent(Bool.self, forKey: .showFeed) ?? true
        showShot = try c.decodeIfPresent(Bool.self, forKey: .showShot) ?? true
        showSize = try c.decodeIfPresent(Bool.self, forKey: .showSize) ?? true
        showTrends = try c.decodeIfPresent(Bool.self, forKey: .showTrends) ?? true
        darkMode = try c.decodeIfPresent(Bool.self, forKey: .darkMode)
        fatherHeight = try c.decodeIfPresent(Double.self, forKey: .fatherHeight)
        motherHeight = try c.decodeIfPresent(Double.self, forKey: .motherHeight)
        quickEntries = try c.decodeIfPresent([QuickEntry].self, forKey: .quickEntries) ?? []
        showLog = try c.decodeIfPresent(Bool.self, forKey: .showLog)
        growthReminderOn = try c.decodeIfPresent(Bool.self, forKey: .growthReminderOn) ?? false
        growthReminderDays = try c.decodeIfPresent(Int.self, forKey: .growthReminderDays) ?? 30
        growthReminderHour = try c.decodeIfPresent(Int.self, forKey: .growthReminderHour) ?? 9
        growthReminderMinute = try c.decodeIfPresent(Int.self, forKey: .growthReminderMinute) ?? 0
        todoReminderOn = try c.decodeIfPresent(Bool.self, forKey: .todoReminderOn) ?? true
        mutedTodoReminders = try c.decodeIfPresent(Set<String>.self, forKey: .mutedTodoReminders) ?? []
    }

    var resolvedQuickEntries: [QuickEntry] {
        if quickEntries.isEmpty { return QuickEntry.builtins }
        // 老版本存过自定义顺序时，把后来新增的内置入口（储奶/喂药/记事本等）补在末尾，
        // 否则升级后新功能在快捷栏里永远看不到
        let existing = Set(quickEntries.map { $0.kind })
        let missing = QuickEntry.builtins.filter { !existing.contains($0.kind) }
        return quickEntries + missing
    }
}

// MARK: - 根状态

struct AppState: Codable, Hashable {
    var children: [Child] = []
    var currentID: UUID? = nil
    var settings = AppSettings()
    /// 删除墓碑：记录已删除条目的 key（如 "todo:<uuid>"），同步合并时据此过滤，
    /// 防止另一端/云端旧快照里的条目在删除后被并集合并"复活"
    var tombstones: Set<String> = []
    /// 最近一次「清空全部数据」的时间戳（UTC yyyy-MM-dd'T'HH:mm:ss）。
    /// 清空不同步删除对方数据：对方会收到提示，自行选择「同步清除 / 忽略」
    var clearedAt: String? = nil

    private enum CodingKeys: String, CodingKey { case children, currentID, settings, tombstones, clearedAt }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        children = try c.decodeIfPresent([Child].self, forKey: .children) ?? []
        currentID = try c.decodeIfPresent(UUID.self, forKey: .currentID)
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        tombstones = try c.decodeIfPresent(Set<String>.self, forKey: .tombstones) ?? []
        clearedAt = try c.decodeIfPresent(String.self, forKey: .clearedAt)
    }
}
