import Foundation

// MARK: - AI 分析提示（本地规则引擎，不联网）

/// 首页顶部那张「AI 分析」卡的内容
struct AISuggestion {
    enum Tone {
        case info, ok, warn, bad

        var emoji: String {
            switch self {
            case .info: return "🤖"
            case .ok: return "😊"
            case .warn: return "⚠️"
            case .bad: return "🚨"
            }
        }
    }

    enum Action: Equatable {
        case entry(String)     // 打开某个快捷入口:"weight" / "bottle" ...
        case vaccine
        case growth
        case none
    }

    var title: String
    var body: String
    var tone: Tone = .info
    var action: Action = .none
    var actionTitle: String = "去记录 →"
}

enum AISuggest {

    /// 按优先级返回当天最该提示的一条
    static func card(for child: Child, settings: AppSettings) -> AISuggestion {
        let now = Date()
        let cal = Calendar.current

        // 0) 喂养模块关掉时，不提示喂养相关内容
        let feedOn = settings.showFeed

        // 1) 体温异常优先
        let recentTemps = child.feeds
            .filter { $0.kind == .temp }
            .filter { now.timeIntervalSince($0.date) < 24 * 3600 }
            .sorted { $0.date > $1.date }
        if let last = recentTemps.first, let t = last.value {
            if t >= 38.5 {
                return AISuggestion(
                    title: String(format: "体温 %.1f℃，建议就医", t),
                    body: "宝宝体温已经超过 38.5℃，如果持续不退或精神差，请尽快去医院，并把这次体温记下来便于医生判断。",
                    tone: .bad, action: .entry("temp"), actionTitle: "再测一次 →")
            }
            if t >= 37.3 {
                return AISuggestion(
                    title: String(format: "体温偏高 %.1f℃", t),
                    body: "先别急着用药，多喝水、少穿一点、隔 1 小时复测。如果继续升高或伴随哭闹嗜睡，及时就医。",
                    tone: .warn, action: .entry("temp"), actionTitle: "复测 →")
            }
        }

        // 2) 完全没有生长记录 → 先补身高体重
        if child.records.isEmpty {
            return AISuggestion(
                title: "缺少身高体重哦",
                body: "补上身高体重，AI 才能依据国家标准动态评估宝宝的生长情况。量一次只要两分钟。",
                tone: .info, action: .entry("weight"), actionTitle: "去记录 →")
        }

        // 3) 有记录但从没记过体重
        if child.records.allSatisfy({ $0.weight == nil }) {
            return AISuggestion(
                title: "缺少体重数据",
                body: "有了体重才能算出身高体重比和百分位，AI 也才能判断长得好不好。",
                tone: .info, action: .entry("weight"), actionTitle: "去记录 →")
        }

        // 4) 距上次测量太久
        if let last = child.latestRecord {
            let days = cal.dateComponents([.day], from: last.date, to: now).day ?? 0
            if days >= 30 {
                return AISuggestion(
                    title: "已经 \(days) 天没量了",
                    body: "0-3 岁建议每月量一次身高体重。今天量一次，就能看到这段时间长了多少。",
                    tone: .warn, action: .entry("weight"), actionTitle: "今天量一次 →")
            }
        }

        // 5) 疫苗到期未种
        if settings.showShot {
            let schedule = GrowthMath.schedule(for: child)
            let due = schedule.filter { $0.status == .due }
            if let first = due.first {
                return AISuggestion(
                    title: "\(due.count) 剂疫苗已到期",
                    body: "最早一针是 \(first.ageLabel) 的 \(first.vaccine.name)，已经超过建议接种时间，尽快去补种。",
                    tone: .warn, action: .vaccine, actionTitle: "看疫苗 →")
            }
        }

        // 6) 今天还没有喂养记录（喂养模块打开时）
        if feedOn {
            let today = child.feeds.filter { cal.isDate($0.date, inSameDayAs: now) && $0.kind != .temp }
            if today.isEmpty && cal.dateComponents([.month], from: child.birthDate, to: now).month ?? 0 < 24 {
                return AISuggestion(
                    title: "今天还没有记录",
                    body: "点右下角麦克风说一句「喝了 150 毫升奶」，或者直接点下面的 + 号，比打字快。",
                    tone: .info, action: .entry("bottle"), actionTitle: "记一条 →")
            }
        }

        // 7) 默认：给一条发育评估
        if let last = child.latestRecord {
            let e = GrowthMath.evaluate(child: child, record: last)
            var pieces: [String] = []
            if let p = e.heightPercentile { pieces.append("身高\(GrowthMath.percentileLabel(p))") }
            if let p = e.weightPercentile { pieces.append("体重\(GrowthMath.percentileLabel(p))") }
            if let bmi = e.bmi { pieces.append(String(format: "BMI %.1f", bmi)) }
            let level = e.heightLevel?.label ?? "正常范围"
            return AISuggestion(
                title: "发育评估：\(level)",
                body: (pieces.isEmpty ? "最近一次测量" : pieces.joined(separator: " · ")) + "，整体在正常范围内。保持规律记录，趋势比单次数字更重要。",
                tone: e.heightLevel?.tone == .bad ? .warn : .ok, action: .growth, actionTitle: "看曲线 →")
        }

        return AISuggestion(
            title: "开始记录吧",
            body: "每天记一条喂养，每月量一次身高体重，数据积累起来才看得出成长曲线。",
            tone: .info, action: .entry("bottle"), actionTitle: "记一条 →")
    }
}
