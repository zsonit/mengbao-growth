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
        case sleep, breast, bottle, diaper

        var id: String { rawValue }

        var title: String {
            switch self {
            case .sleep: return "睡眠"
            case .breast: return "亲喂"
            case .bottle: return "瓶喂"
            case .diaper: return "尿布"
            }
        }

        var icon: String {
            switch self {
            case .sleep: return "😴"
            case .breast: return "🤱"
            case .bottle: return "🍼"
            case .diaper: return "🧷"
            }
        }

        var unit: String {
            switch self {
            case .sleep, .breast: return "分钟"
            case .bottle: return "ml"
            case .diaper: return "次"
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
    var note: String = ""

    var summary: String {
        switch kind {
        case .sleep: return "\(minutes ?? 0) 分钟"
        case .breast: return "\((side ?? "左")) \(minutes.map { "\($0) 分钟" } ?? "")"
        case .bottle: return "\(Int(ml ?? 0)) ml"
        case .diaper: return diaperKind ?? "小便"
        }
    }
}

// MARK: - 鞋服尺码

struct SizeRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var footLength: Double?
    var height: Double?
    var note: String = ""
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
    var createdAt = Date()

    var records: [GrowthRecord] = []
    var feeds: [FeedLog] = []
    var sizes: [SizeRecord] = []
    var shots: [String: ShotRecord] = [:]
    var todos: [TodoItem] = []

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

// MARK: - 设置

struct AppSettings: Codable {
    var weightUnit: String = "kg"          // kg / 斤
    var showFeed: Bool = true
    var showShot: Bool = true
    var darkMode: Bool? = nil              // nil = 跟随系统
    var fatherHeight: Double? = nil
    var motherHeight: Double? = nil
}

// MARK: - 根状态

struct AppState: Codable {
    var children: [Child] = []
    var currentID: UUID? = nil
    var settings = AppSettings()
}
