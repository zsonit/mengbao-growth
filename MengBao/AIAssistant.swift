import Foundation

// MARK: - AI 语音指令：把一句话变成 App 里的操作
//
// 流程：语音识别出文字 → 大模型按固定 JSON 协议回「怎么说 + 做什么」
//       → 本地校验后写进 Store（写入即触发同步）→ 展示结果，可一键撤销。
// 模型只负责理解，不直接碰数据；数值都有本地校验，宁可少记也不瞎记。

struct AIActionItem: Identifiable {
    let id = UUID()
    /// 展示用文案，例如「瓶喂 120 ml · 10:00」
    let label: String
    /// 撤销这次写入
    let undo: () -> Void
}

struct AIPlan {
    var reply: String
    var items: [AIActionItem]
    var openPage: String?
}

enum AIAssistant {

    /// 页面标识 → 中文名（也用来校验模型给的值）
    static let pages: [(key: String, name: String)] = [
        ("home", "首页"), ("feed", "喂养"), ("trends", "成长趋势"), ("history", "记录历史"),
        ("todo", "待办清单"), ("vaccine", "接种"), ("size", "鞋服尺码"), ("growth", "生长曲线"),
        ("teeth", "换牙"), ("profile", "我的"),
    ]

    // MARK: 系统提示词

    static func systemPrompt(child: Child?) -> String {
        let cal = Calendar.current
        let now = Date()
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy-MM-dd HH:mm"
        let stamp = df.string(from: now)
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: now)
        let tomorrow = df.string(from: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        let weekday = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][
            (cal.component(.weekday, from: now) + 5) % 7
        ]

        var baby = "（还没有宝宝档案）"
        var todayStat = ""
        if let c = child {
            let age = GrowthMath.ageText(from: c.birthDate)
            baby = "\(age)，\(c.sex == .girl ? "女孩" : "男孩")"
            let feeds = c.feeds.filter { cal.isDate($0.date, inSameDayAs: now) }
            let sleep = feeds.filter { $0.kind == .sleep }.reduce(0) { $0 + ($1.minutes ?? 0) }
            let milk = Int(feeds.filter { $0.kind == .bottle }.reduce(0.0) { $0 + ($1.ml ?? 0) })
            let diaper = feeds.filter { $0.kind == .diaper }.count
            let solid = feeds.filter { $0.kind == .solid }.count
            let pump = Int(feeds.filter { $0.kind == .pumping }.reduce(0.0) { $0 + ($1.ml ?? 0) })
            todayStat = "今天已记：睡眠 \(sleep) 分钟、奶量 \(milk) ml、尿布 \(diaper) 次、吸奶 \(pump) ml、辅食 \(solid) 次。"
        }

        let pageList = pages.map { "\($0.key)" }.joined(separator: "|")

        return """
        你是「萌宝成长」App 里的中文语音助手。家长说一句话，你要判断他想做什么：能变成 App 操作的就执行，只是提问就用一句话回答。宝宝：\(baby)。
        现在是 \(stamp)（\(weekday)）。\(todayStat)今天是 \(today)，明天是 \(tomorrow)。

        只输出一个 JSON 对象，不要输出任何其它文字，不要用 ``` 包裹：
        {"reply":"给家长看的一句话，口语，不超过 40 字","actions":[...]}

        actions 只能是下面几种，没有要执行的就给 []：
        1) 喂养/护理记录
        {"type":"feed","kind":"sleep|breast|bottle|pumping|diaper|solid|supplement|temp|custom",
         "minutes":整数分钟或null,"ml":数字或null,"side":"左|右|双侧或null",
         "diaperKind":"小便|大便|混合或null","value":体温等数字或null,"note":"简短备注可为空","time":"HH:mm或null"}
        2) 待办
        {"type":"todo","title":"要做什么","due":"yyyy-MM-dd 或 null"}
        3) 生长测量（身高体重头围脚长，单位 cm / kg）
        {"type":"growth","height":null,"weight":null,"headCirc":null,"footLength":null,"note":""}
        4) 鞋服尺码（只要脚长和身高就够）
        {"type":"size","footLength":null,"height":null,"note":""}
        5) 打开页面
        {"type":"page","page":"\(pageList)"}

        规则：
        - 一句话里有多件事，就拆成多条 actions，按说的顺序排。
        - 时长换算：半小时=30，一个多小时=70，两小时=120，一刻钟=15。
        - 数量换算：一百二=120，两百=200，"毫升/ml/CC"都是 ml。
        - 只写家长明确说过的数值，没说就填 null，绝对不要自己编。
        - 时间：只说"刚才/刚刚/今天"就填 null；说了"早上七点""下午三点半""晚上八点"就换成 24 小时制 HH:mm；说了"昨天"就在 note 里注明【昨天】。
        - 家长只是在问问题（例如"睡得够不够""能不能加辅食"），actions 给 []，答案写在 reply 里。
        - 家长在反映 App 本身的问题（界面显示不全、有缺口、闪退、卡、按钮点不动等），不是在记录宝宝数据：actions 给 []，reply 只回一句「收到，这条记下了，会尽快修」，绝不猜测技术原因，不要建议去改手机设置、显示大小或升级系统。
        - 健康相关：发烧≥38.5℃、抽搐、呼吸困难、精神差、持续呕吐 → 提醒尽快就医；不确定就直说不知道，不要编。
        - reply 里最多一个表情符号，不要 Markdown、不要分点罗列。

        示例：
        家长："宝宝十点喝了120的奶" → {"reply":"记下了：10:00 瓶喂 120 ml","actions":[{"type":"feed","kind":"bottle","ml":120,"minutes":null,"side":null,"diaperKind":null,"value":null,"note":"","time":"10:00"}]}
        家长："刚换了尿布是大便，然后明天记得买纸尿裤" → {"reply":"记下大便一次，明天提醒你买纸尿裤","actions":[{"type":"feed","kind":"diaper","minutes":null,"ml":null,"side":null,"diaperKind":"大便","value":null,"note":"","time":null},{"type":"todo","title":"买纸尿裤","due":"\(tomorrow)"}]}
        家长："宝宝今天睡得怎么样" → {"reply":"今天一共睡了 2 小时 10 分钟，比昨天略少，晚上可以早点哄睡。","actions":[]}
        """
    }

    // MARK: 请求 + 解析

    static func interpret(
        text: String,
        child: Child?,
        store: Store,
        model: String,
        history: [[String: String]] = [],
    ) async throws -> AIPlan {
        let raw = try await AIClient.shared.stream(
            model: model,
            messages: [["role": "system", "content": systemPrompt(child: child)]] + history
                + [["role": "user", "content": text]]
        )
        let parsed = parse(raw)
        let applied = execute(actions: parsed.actions, store: store)
        return AIPlan(reply: parsed.reply, items: applied.items, openPage: applied.page)
    }

    /// 模型偶尔会裹 ``` 或加一句话，这里只抠第一个 { 到最后一个 }
    static func parse(_ raw: String) -> (reply: String, actions: [[String: Any]]) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start < end
        else {
            return (fallbackText(trimmed), [])
        }
        let json = String(trimmed[start...end])
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return (fallbackText(trimmed), [])
        }
        let reply = (obj["reply"] as? String) ?? ""
        let actions = (obj["actions"] as? [[String: Any]]) ?? []
        return (reply.isEmpty ? fallbackText(trimmed) : reply, actions)
    }

    private static func fallbackText(_ raw: String) -> String {
        let clean = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "我没太听懂，再说一次？" }
        return String(clean.prefix(160))
    }

    // MARK: 执行

    private static func execute(actions: [[String: Any]], store: Store) -> (items: [AIActionItem], page: String?) {
        var items: [AIActionItem] = []
        var page: String?

        for a in actions {
            switch (a["type"] as? String) ?? "" {
            case "feed":
                if let item = applyFeed(a, store: store) { items.append(item) }
            case "todo":
                if let item = applyTodo(a, store: store) { items.append(item) }
            case "growth":
                if let item = applyGrowth(a, store: store) { items.append(item) }
            case "size":
                if let item = applySize(a, store: store) { items.append(item) }
            case "page":
                if let p = a["page"] as? String, pages.contains(where: { $0.key == p }) { page = p }
            default:
                continue
            }
        }
        return (items, page)
    }

    private static func num(_ a: [String: Any], _ key: String) -> Double? {
        if let d = a[key] as? Double { return d }
        if let i = a[key] as? Int { return Double(i) }
        if let s = a[key] as? String { return Double(s.replacingOccurrences(of: ",", with: "")) }
        return nil
    }

    private static func dateFrom(_ time: String?) -> Date {
        let now = Date()
        guard let t = time, !t.isEmpty else { return now }
        let parts = t.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return now }
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: now) ?? now
    }

    private static func hhmm(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    private static func kind(_ raw: String?) -> FeedLog.Kind? {
        switch raw {
        case "sleep": return .sleep
        case "breast": return .breast
        case "bottle": return .bottle
        case "pumping": return .pumping
        case "storage": return .storage
        case "diaper": return .diaper
        case "solid": return .solid
        case "supplement": return .supplement
        case "medicine": return .medicine
        case "notebook": return .notebook
        case "temp": return .temp
        case "custom": return .custom
        default: return nil
        }
    }

    private static func applyFeed(_ a: [String: Any], store: Store) -> AIActionItem? {
        guard let k = kind(a["kind"] as? String) else { return nil }
        let at = dateFrom(a["time"] as? String)
        var log = FeedLog(date: at, kind: k)

        switch k {
        case .sleep, .breast:
            guard let m = num(a, "minutes"), m > 0, m < 24 * 60 else { return nil }
            log.minutes = Int(m.rounded())
        case .bottle, .pumping:
            guard let ml = num(a, "ml"), ml > 0, ml < 2000 else { return nil }
            log.ml = ml
        case .temp:
            guard let v = num(a, "value"), v > 30, v < 45 else { return nil }
            log.value = v
        case .diaper:
            log.diaperKind = (a["diaperKind"] as? String) ?? "小便"
        case .storage:
            guard let ml = num(a, "ml"), ml > 0, ml < 2000 else { return nil }
            log.ml = ml
        case .medicine, .notebook, .solid, .supplement, .custom:
            break
        }
        if k == .breast, let s = a["side"] as? String, !s.isEmpty { log.side = s }
        let note = (a["note"] as? String) ?? ""
        if !note.isEmpty { log.note = note }

        store.addFeed(log)
        let id = log.id
        let label = "\(k.title)\(log.summary.isEmpty ? "" : " · " + log.summary) · \(hhmm(at))"
        return AIActionItem(label: label) { store.deleteFeed(id) }
    }

    private static func applyTodo(_ a: [String: Any], store: Store) -> AIActionItem? {
        let title = ((a["title"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        var due: Date?
        if let s = a["due"] as? String, !s.isEmpty {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"
            due = f.date(from: s)
        }
        let todo = TodoItem(title: title, due: due)
        store.addTodo(todo)
        let id = todo.id
        let label = due == nil ? "待办 · \(title)" : "待办 · \(title)（\(GrowthMath.shortDate(due!))）"
        return AIActionItem(label: label) { store.deleteTodo(id) }
    }

    private static func applyGrowth(_ a: [String: Any], store: Store) -> AIActionItem? {
        var r = GrowthRecord(date: Date())
        r.height = num(a, "height").flatMap { (30...200).contains($0) ? $0 : nil }
        r.weight = num(a, "weight").flatMap { (0.5...80).contains($0) ? $0 : nil }
        r.headCirc = num(a, "headCirc").flatMap { (20...70).contains($0) ? $0 : nil }
        r.footLength = num(a, "footLength").flatMap { (3...40).contains($0) ? $0 : nil }
        r.note = (a["note"] as? String) ?? ""
        guard r.hasAnyValue else { return nil }

        store.addRecord(r)
        let id = r.id
        var parts: [String] = []
        if let h = r.height { parts.append(String(format: "身高 %.1f cm", h)) }
        if let w = r.weight { parts.append(String(format: "体重 %.2f kg", w)) }
        if let hc = r.headCirc { parts.append(String(format: "头围 %.1f cm", hc)) }
        if let fl = r.footLength { parts.append(String(format: "脚长 %.1f cm", fl)) }
        return AIActionItem(label: "生长测量 · " + parts.joined(separator: "、")) {
            store.deleteRecord(id)
        }
    }

    private static func applySize(_ a: [String: Any], store: Store) -> AIActionItem? {
        var s = SizeRecord(date: Date())
        s.footLength = num(a, "footLength").flatMap { (3...40).contains($0) ? $0 : nil }
        s.height = num(a, "height").flatMap { (30...200).contains($0) ? $0 : nil }
        s.note = (a["note"] as? String) ?? ""
        guard s.footLength != nil || s.height != nil else { return nil }

        store.addSize(s)
        var parts: [String] = []
        if let f = s.footLength { parts.append(String(format: "脚长 %.1f cm", f)) }
        if let h = s.height { parts.append(String(format: "身高 %.1f cm", h)) }
        return AIActionItem(label: "鞋服尺码 · " + parts.joined(separator: "、")) {
            store.updateCurrent { c in c.sizes.removeAll { $0.date == s.date && $0.footLength == s.footLength } }
        }
    }
}
