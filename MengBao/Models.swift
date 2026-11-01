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
        case sleep, breast, bottle, pumping, diaper, solid, supplement, temp, custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .sleep: return "睡眠"
            case .breast: return "亲喂"
            case .bottle: return "瓶喂"
            case .pumping: return "吸奶"
            case .diaper: return "尿布"
            case .solid: return "辅食"
            case .supplement: return "补剂"
            case .temp: return "体温"
            case .custom: return "记录"
            }
        }

        var icon: String {
            switch self {
            case .sleep: return "😴"
            case .breast: return "🤱"
            case .bottle: return "🍼"
            case .pumping: return "🧴"
            case .diaper: return "🧷"
            case .solid: return "🍚"
            case .supplement: return "💊"
            case .temp: return "🌡️"
            case .custom: return "📝"
            }
        }

        var unit: String {
            switch self {
            case .sleep, .breast, .pumping: return "分钟"
            case .bottle: return "ml"
            case .diaper: return "次"
            case .solid: return ""
            case .supplement: return ""
            case .temp: return "℃"
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
    /// 通用数值位：体温（℃）、辅食克数等
    var value: Double?
    var note: String = ""

    var summary: String {
        switch kind {
        case .sleep: return "\(minutes ?? 0) 分钟"
        case .breast: return "\((side ?? "左")) \(minutes.map { "\($0) 分钟" } ?? "")"
        case .bottle: return "\(Int(ml ?? 0)) ml"
        case .pumping: return "\(Int(ml ?? 0)) ml"
        case .diaper: return diaperKind ?? "小便"
        case .solid: return note.isEmpty ? "已添加辅食" : note
        case .supplement: return note.isEmpty ? "已服用" : note
        case .temp: return String(format: "%.1f ℃", value ?? 36.5)
        case .custom: return note.isEmpty ? "记录" : note
        }
    }

    /// 语音/一键录入时给 AI 卡用的自然语言摘要
    var speakText: String {
        switch kind {
        case .sleep: return "睡了 \(minutes ?? 0) 分钟"
        case .breast: return "亲喂 \(side ?? "左") 侧 \(minutes ?? 0) 分钟"
        case .bottle: return "喝了 \(Int(ml ?? 0)) 毫升奶"
        case .pumping: return "吸奶 \(Int(ml ?? 0)) 毫升"
        case .diaper: return diaperKind ?? "小便"
        case .solid: return "吃了 \(note)"
        case .supplement: return "补了 \(note)"
        case .temp: return String(format: "体温 %.1f 度", value ?? 36.5)
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
    var topLength: Double?     // 衣长
    var sleeve: Double?        // 袖长
    var pantsLength: Double?   // 裤长
    var shoeSize: Int?         // 穿鞋码数（中国码）
    var shoeInner: Double?     // 鞋内长
    var note: String = ""

    /// 填了几项（含备注）：用来挑「最完整」的那条，也是去重时的优先级
    var filledCount: Int {
        let values: [Double?] = [footLength, height, shoulder, waist, hip, thigh, calf,
                                 topLength, sleeve, pantsLength, shoeInner,
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
    var updatedAt: Date? = nil            // 配对同步：档案最后一次修改时刻（冲突时后改的赢）


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
        QuickEntry(id: "sleep", kind: "sleep", title: "睡眠", icon: "😴"),
        QuickEntry(id: "diaper", kind: "diaper", title: "尿布", icon: "🧷"),
        QuickEntry(id: "solid", kind: "solid", title: "辅食", icon: "🍚"),
        QuickEntry(id: "supplement", kind: "supplement", title: "补剂", icon: "💊"),
        QuickEntry(id: "temp", kind: "temp", title: "体温", icon: "🌡️"),
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
    var showLog: Bool? = nil               // 运行日志（独立开关；可选类型保证旧数据可解码）
    var darkMode: Bool? = nil              // nil = 跟随系统
    var fatherHeight: Double? = nil
    var motherHeight: Double? = nil
    /// 空数组 = 用内置默认顺序；用户改过之后写入完整列表
    var quickEntries: [QuickEntry] = []

    // 宽松解码：老版本备份缺哪个字段都用默认值兜底，避免升级/恢复备份时整份数据解不出来
    init(weightUnit: String = "kg", showFeed: Bool = true, showShot: Bool = true,
         showSize: Bool = true, darkMode: Bool? = nil, fatherHeight: Double? = nil,
         motherHeight: Double? = nil, quickEntries: [QuickEntry] = [], showLog: Bool? = nil) {
        self.weightUnit = weightUnit
        self.showFeed = showFeed
        self.showShot = showShot
        self.showSize = showSize
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
        darkMode = try c.decodeIfPresent(Bool.self, forKey: .darkMode)
        fatherHeight = try c.decodeIfPresent(Double.self, forKey: .fatherHeight)
        motherHeight = try c.decodeIfPresent(Double.self, forKey: .motherHeight)
        quickEntries = try c.decodeIfPresent([QuickEntry].self, forKey: .quickEntries) ?? []
        showLog = try c.decodeIfPresent(Bool.self, forKey: .showLog)
    }

    var resolvedQuickEntries: [QuickEntry] {
        quickEntries.isEmpty ? QuickEntry.builtins : quickEntries
    }
}

// MARK: - 根状态

struct AppState: Codable, Hashable {
    var children: [Child] = []
    var currentID: UUID? = nil
    var settings = AppSettings()
}
