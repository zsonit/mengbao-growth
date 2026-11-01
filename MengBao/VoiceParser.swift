import Foundation

// MARK: - 语音/文字 → 记录（纯本地规则，不联网、不上传）

/// 一句话解析结果。`kind == nil` 表示没听懂。
struct VoiceParseResult {
    var kind: String?                    // bottle/breast/pumping/sleep/diaper/solid/supplement/temp/custom/growth
    var entryId: String?                 // 命中的快捷入口 id
    var value: Double?                   // 体温 / 数值
    var minutes: Int?
    var ml: Double?
    var side: String?
    var diaperKind: String?
    var note: String = ""
    var hour: Int?                       // 若句子里带了「下午3点」这类时间
    var text: String = ""                // 原始文本

    var ok: Bool { kind != nil }

    /// 给确认卡显示的摘要
    var summary: String {
        guard let kind else { return "没听懂" }
        switch kind {
        case "bottle": return "瓶喂 \(Int(ml ?? 0)) ml"
        case "pumping": return "吸奶 \(Int(ml ?? 0)) ml"
        case "breast": return "亲喂 \(side ?? "左")侧 \(minutes.map { "\($0) 分钟" } ?? "")".trimmed()
        case "sleep": return "睡眠 \(minutes ?? 0) 分钟"
        case "diaper": return "尿布 · \(diaperKind ?? "小便")"
        case "solid": return note.isEmpty ? "辅食" : "辅食 · \(note)"
        case "supplement": return note.isEmpty ? "补剂" : "补剂 · \(note)"
        case "temp": return String(format: "体温 %.1f ℃", value ?? 36.5)
        case "growth":
            var parts: [String] = []
            if let v = value, let unit = growthUnit { parts.append(String(format: "%@ %.1f cm", unit.0, v)) }
            return parts.isEmpty ? "生长记录" : parts.joined(separator: " · ")
        default: return note.isEmpty ? "记录" : note
        }
    }

    /// growth 类型时用：("身高"/"体重"/"头围", 值)
    var growthUnit: (String, String)? {
        guard let id = entryId else { return nil }
        switch id {
        case "height": return ("身高", "cm")
        case "weight": return ("体重", "kg")
        case "head": return ("头围", "cm")
        default: return nil
        }
    }
}

enum VoiceParser {

    // MARK: 中文数字

    private static let cnDigits: [Character: Int] = [
        "零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
        "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
    ]

    /// 把中文数字换成阿拉伯数字：「二十三」→「23」「一个半」→「1.5」
    static func normalizeNumbers(_ input: String) -> String {
        var text = input
        // 「两个半小时」这类要先整体换算，否则会被「半小时→30分钟」的替换拆坏
        text = replaceDurationHalves(text)
        text = text.replacingOccurrences(of: "半个小时", with: "30分钟")
        text = text.replacingOccurrences(of: "半小时", with: "30分钟")
        text = text.replacingOccurrences(of: "一个钟", with: "60分钟")
        text = text.replacingOccurrences(of: "一刻钟", with: "15分钟")

        var result = ""
        var current = ""     // 累积的中文数字串
        var currentValue = 0

        func flush() {
            if !current.isEmpty {
                result += "\(currentValue)"
                current = ""
                currentValue = 0
            }
        }

        for ch in text {
            if let d = cnDigits[ch] {
                currentValue = currentValue * 10 + d
                current.append(ch)
            } else if ch == "十" {
                currentValue = (currentValue == 0 ? 1 : currentValue) * 10
                current.append(ch)
            } else if ch == "百" {
                currentValue = (currentValue == 0 ? 1 : currentValue) * 100
                current.append(ch)
            } else if ch == "半", !current.isEmpty {
                flush()
                result += ".5"
            } else {
                flush()
                result.append(ch)
            }
        }
        flush()
        return result
    }

    private static func cnNumberToInt(_ s: String) -> Int {
        var acc = 0
        var total = 0
        for ch in s {
            if let d = cnDigits[ch] {
                acc = acc * 10 + d
            } else if ch == "十" {
                total += (acc == 0 ? 1 : acc) * 10
                acc = 0
            } else if ch == "百" {
                total += (acc == 0 ? 1 : acc) * 100
                acc = 0
            }
        }
        return total + acc
    }

    /// 「两个半小时」→「150分钟」（逐段替换，保留其余文本）
    private static func replaceDurationHalves(_ input: String) -> String {
        guard let re = try? NSRegularExpression(pattern: "([0-9]+|[零〇一二两三四五六七八九十]+)\\s*个?\\s*半\\s*(?:小时|钟头)") else { return input }
        let ns = input as NSString
        let matches = re.matches(in: input, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return input }
        var result = ""
        var cursor = 0
        for m in matches {
            let n = cnNumberToInt(ns.substring(with: m.range(at: 1)))
            result += ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
            result += "\(n * 60 + 30)分钟"
            cursor = m.range.upperBound
        }
        result += ns.substring(from: cursor)
        return result
    }

    // MARK: 数字提取

    private static func numbers(in text: String) -> [Double] {
        let pattern = "([0-9]+(?:\\.[0-9]+)?)"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
            Double(ns.substring(with: $0.range(at: 1)))
        }
    }

    private static func firstNumber(in text: String, in range: ClosedRange<Double>) -> Double? {
        numbers(in: text).first { range.contains($0) }
    }

    /// 提取时长（分钟）：支持「2小时」「1小时20分钟」「40分钟」
    private static func duration(in text: String) -> Int? {
        var total: Int?
        if let h = firstMatch(text, "(\\d+(?:\\.\\d+)?)\\s*(?:个)?\\s*小时") {
            total = Int(Double(h)! * 60)
        }
        if let m = firstMatch(text, "(\\d+)\\s*分钟") {
            total = (total ?? 0) + Int(m)!
        }
        if let h = firstMatch(text, "(\\d+(?:\\.\\d+)?)\\s*(?:个)?\\s*h"), total == nil {
            total = Int((Double(h) ?? 0) * 60)
        }
        return total
    }

    private static func firstMatch(_ text: String, _ pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        if m.numberOfRanges > 1 {
            return ns.substring(with: m.range(at: 1))
        }
        return ns.substring(with: m.range)
    }

    private static func containsAny(_ text: String, _ keys: [String]) -> Bool {
        keys.contains { text.contains($0) }
    }

    // MARK: 时间（口语）

    private static func clockHour(in text: String) -> Int? {
        guard let h = firstMatch(text, "(\\d{1,2})\\s*[点時时]") , let hour = Int(h), hour >= 0, hour <= 23 else { return nil }
        var value = hour
        if containsAny(text, ["下午", "晚上", "傍晚"]) && value < 12 { value += 12 }
        if containsAny(text, ["中午"]) && value < 12 { value += 12 }
        return value
    }

    // MARK: 主入口

    static func parse(_ raw: String) -> VoiceParseResult {
        let original = raw.trimmed()
        let text = normalizeNumbers(original)
        var r = VoiceParseResult(text: original)

        // 1) 体温
        if containsAny(text, ["体温", "发烧", "发热", "烧到", "度"]) {
            if let v = firstNumber(in: text, in: 34...43) {
                r.kind = "temp"; r.entryId = "temp"; r.value = v
                return r
            }
        }

        // 2) 身高 / 体重 / 头围
        if containsAny(text, ["身高", "身长", "长高"]) {
            if let v = firstNumber(in: text, in: 30...200) {
                r.kind = "growth"; r.entryId = "height"; r.value = v
                return r
            }
        }
        if containsAny(text, ["体重", "重了", "称了"]) {
            if let v = firstNumber(in: text, in: 1...120) {
                r.kind = "growth"; r.entryId = "weight"; r.value = v
                return r
            }
        }
        if containsAny(text, ["头围"]) {
            if let v = firstNumber(in: text, in: 20...70) {
                r.kind = "growth"; r.entryId = "head"; r.value = v
                return r
            }
        }

        // 3) 吸奶
        if containsAny(text, ["吸奶", "泵奶", "挤奶", "吸出来"]) {
            r.kind = "pumping"; r.entryId = "pumping"
            r.ml = firstNumber(in: text, in: 5...500)
            return r
        }

        // 4) 亲喂
        if containsAny(text, ["亲喂", "母乳", "吃奶", "喂了奶"]) && !containsAny(text, ["奶瓶", "奶粉"]) {
            if containsAny(text, ["左", "右"]) {
                r.kind = "breast"; r.entryId = "breast"
                r.side = text.contains("右") ? "右" : "左"
                r.minutes = duration(in: text)
                return r
            }
            if let m = duration(in: text), m > 0 {
                r.kind = "breast"; r.entryId = "breast"; r.side = "左"; r.minutes = m
                return r
            }
        }

        // 5) 瓶喂 / 奶粉 / 喝奶
        if containsAny(text, ["奶", "毫升", "ml", "ML"]) {
            let ml = firstNumber(in: text, in: 10...500)
            if let ml {
                r.kind = "bottle"; r.entryId = "bottle"; r.ml = ml
                return r
            }
            // 没说毫升，但明确是喂奶动作
            if containsAny(text, ["喂了", "喝了", "喝奶", "吃了奶", "奶粉", "奶瓶"]) {
                r.kind = "bottle"; r.entryId = "bottle"; r.ml = 120
                r.note = "未说毫升数，按 120ml 记"
                return r
            }
        }

        // 6) 睡眠
        if containsAny(text, ["睡", "午觉", "小睡", "眯了"]) {
            r.kind = "sleep"; r.entryId = "sleep"
            r.minutes = duration(in: text) ?? 60
            return r
        }

        // 7) 尿布
        if containsAny(text, ["尿布", "尿不湿", "换尿", "尿了", "拉了", "臭臭", "便便", "大便", "小便"]) {
            r.kind = "diaper"; r.entryId = "diaper"
            r.diaperKind = containsAny(text, ["大便", "臭臭", "便便", "拉了"]) ? "大便" : "小便"
            return r
        }

        // 8) 辅食
        if containsAny(text, ["辅食", "吃了", "米粉", "粥", "面条", "果泥", "菜泥", "肉泥", "蛋黄", "鸡蛋", "水果", "香蕉", "苹果"]) {
            r.kind = "solid"; r.entryId = "solid"
            r.note = foodWords(in: text)
            return r
        }

        // 9) 补剂
        if containsAny(text, ["维生素", "维D", "D3", "AD", "钙", "铁剂", "补铁", "锌", "DHA", "益生菌", "补剂"]) {
            r.kind = "supplement"; r.entryId = "supplement"
            r.note = supplementWords(in: text)
            return r
        }

        // 10) 兜底：存一条备注
        if !original.isEmpty {
            r.kind = "custom"; r.entryId = nil; r.note = original
        }
        return r
    }

    private static func foodWords(in text: String) -> String {
        let keywords = ["米粉", "粥", "面条", "烂面", "果泥", "菜泥", "肉泥", "蛋黄", "鸡蛋", "香蕉", "苹果", "南瓜", "土豆", "牛油果", "西兰花", "胡萝卜", "虾", "鱼", "肝粉", "豆腐", "酸奶"]
        let hit = keywords.filter { text.contains($0) }
        if !hit.isEmpty { return hit.joined(separator: "、") }
        // 「吃了 XX」直接取后半段
        if let range = text.range(of: "吃了") {
            let tail = String(text[range.upperBound...]).trimmed()
            return tail.isEmpty ? "" : tail
        }
        return ""
    }

    private static func supplementWords(in text: String) -> String {
        let keywords = ["维生素D3", "维生素D", "维D", "D3", "AD滴剂", "AD", "钙剂", "钙", "铁剂", "补铁", "锌", "DHA", "益生菌"]
        let hit = keywords.filter { text.contains($0) }
        return hit.first ?? "补剂"
    }

    // MARK: - 长语音：整段话拆成多条记录

    /// 口头连接词，当作句子分隔
    private static let connectors = try! NSRegularExpression(pattern: "(?:然后|还有|接着|另外|再来|以及|同时|其次|后面|之后)")

    /// 句子分隔符（不含「、」，避免拆散「米粉、蛋黄」这类食物列举）
    private static let sentenceDelim = try! NSRegularExpression(pattern: "[，。！？；,!?;\\n\\r]+")

    /// 动词型起点关键词：每个出现位置都是一条记录的开始。
    /// 语音识别出的文本通常没有标点，只靠标点拆不开，必须按动词起点切。
    private static let verbStarts = [
        "体温", "发烧", "发热", "烧到", "身高", "身长", "长高", "体重", "称了", "称重", "头围",
        "亲喂", "吸奶", "泵奶", "挤奶", "吸出来", "喂奶", "喂了", "喝", "吃", "睡", "午觉", "小睡", "眯了",
        "尿", "拉了", "臭臭", "便便", "大便", "小便", "换尿",
        "辅食", "米粉", "果泥", "菜泥", "肉泥", "蛋黄", "鸡蛋", "香蕉", "苹果", "粥", "面条",
        "维生素", "维D", "D3", "钙", "铁剂", "补铁", "锌", "DHA", "益生菌", "补剂",
    ]

    private static func trimEdge(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: "，。！？；,!?; \n\r"))
    }

    private static func allRanges(of keyword: String, in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start = text.startIndex
        while let r = text.range(of: keyword, range: start..<text.endIndex) {
            ranges.append(r)
            start = r.upperBound
        }
        return ranges
    }

    /// 把一大段话拆成一句一条：连接词→逗号，标点+动词起点为切割点，碎段并入相邻段。
    static func splitSegments(_ raw: String) -> [String] {
        let original = raw.trimmed()
        if original.isEmpty { return [] }
        let text = connectors.stringByReplacingMatches(
            in: original, range: NSRange(location: 0, length: (original as NSString).length),
            withTemplate: "，",
        )

        var cuts = Set<Int>()
        let ns = text as NSString
        sentenceDelim.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .forEach { cuts.insert($0.range.location) }
        for kw in verbStarts {
            for r in allRanges(of: kw, in: text) {
                cuts.insert(text.distance(from: text.startIndex, to: r.lowerBound))
            }
        }
        if cuts.isEmpty { return [trimEdge(text)] }

        let bounds = ([0] + cuts.filter { $0 >= 0 && $0 < ns.length }).sorted()
        var segs: [String] = []
        for (i, start) in bounds.enumerated() {
            let end = i + 1 < bounds.count ? bounds[i + 1] : ns.length
            let s = trimEdge(ns.substring(with: NSRange(location: start, length: end - start)))
            if s.isEmpty { continue }
            if s.count <= 2 && !s.contains(where: { $0.isNumber }), !segs.isEmpty {
                segs[segs.count - 1] += s
            } else {
                segs.append(s)
            }
        }
        if segs.count > 1, segs[0].count <= 2, !segs[0].contains(where: { $0.isNumber }) {
            segs[1] = segs[0] + segs[1]
            segs.removeFirst()
        }
        return segs
    }

    /// 长语音解析：逐句 parse；归类不了的进 unknown（确认页提示，不乱记）。
    static func parseAll(_ raw: String) -> (results: [VoiceParseResult], unknown: [String]) {
        let segments = splitSegments(raw)
        if segments.isEmpty { return ([], []) }
        var results: [VoiceParseResult] = []
        var unknown: [String] = []
        for seg in segments {
            let r = parse(seg)
            if !r.ok || r.kind == "custom" {
                unknown.append(seg)
                continue
            }
            // 被切碎的纯动词短语（如「米粉和蛋黄都 / 吃了」）：与上一条同类型且无实质内容，跳过
            if (r.kind == "solid" || r.kind == "supplement"), r.note.isEmpty,
               results.last?.kind == r.kind {
                continue
            }
            results.append(r)
        }
        return (results, unknown)
    }
}

// MARK: - 常用选项（弹层里的快捷 chips）

enum EntryPresets {
    static let foods = ["米粉", "土豆泥", "南瓜泥", "牛油果泥", "肉泥", "蛋黄", "苹果泥", "香蕉泥"]
    static let supplements = ["维生素D3", "AD滴剂", "钙剂", "铁剂", "DHA", "益生菌"]
    static let diaperKinds = ["小便", "大便", "混合"]
    static let milkAmounts: [Double] = [60, 90, 120, 150, 180, 210, 240]
    static let sleepMinutes: [Int] = [15, 30, 45, 60, 90, 120]
}

extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
