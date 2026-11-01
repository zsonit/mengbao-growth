import Foundation

// MARK: - 语音说出来的待办

struct TodoDraft: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var due: Date?
}

/// 待办语音解析：一整段话 → 若干条待办，顺带识别「明天 / 下周三 / 3 天后 / 10月8号」这类日期。
///
/// 和记喂养的 `VoiceParser` 分开：那边按动作切段（喝/睡/尿/体温），
/// 这里按标点和口头连接词切，因为「记得买维生素 D3 和钙片」这种句子不能被拆成两条。
enum TodoParser {

    /// 句子分隔（含顿号：说待办时「买苹果、香蕉」也确实是两件事时再切，见下）
    private static let delimiters = try! NSRegularExpression(pattern: "[。！？；,.!?;\\n\\r]+")
    /// 口头连接词：一句话里连说好几件事时的真实分界
    private static let connectors = try! NSRegularExpression(
        pattern: "(?:然后|还有|接着|另外|再来|顺便|同时|之后|以及|最后)",
    )
    /// 顿号、逗号：待办里多半是并列的几件事
    private static let softDelimiters = try! NSRegularExpression(pattern: "[，、]+")

    /// 常见口头前缀，去掉后标题更干净
    private static let prefixes = [
        "记得要", "要记得", "记得", "别忘了", "不要忘了", "别忘记", "提醒我", "帮我", "安排一下", "需要", "我得", "我要",
    ]

    static func parse(_ raw: String, today: Date = Date()) -> [TodoDraft] {
        var out: [TodoDraft] = []
        for segment in split(raw) {
            guard let draft = analyze(segment, today: today) else { continue }
            if out.contains(where: { $0.title == draft.title && $0.due == draft.due }) { continue }
            out.append(draft)
        }
        return out
    }

    // MARK: 切段

    static func split(_ raw: String) -> [String] {
        let original = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return [] }

        let text = replace(connectors, in: original, with: "。")
        var pieces: [String] = []

        // 先按句号类切：这些一定是分界
        for hard in splitBy(delimiters, text) {
            // 再按逗号/顿号切，但太短的碎片并回上一段（「买牛奶，还有鸡蛋」）
            var acc: [String] = []
            for soft in splitBy(softDelimiters, hard) {
                let s = clean(soft)
                if s.isEmpty { continue }
                if s.count <= 1 && !s.contains(where: { $0.isNumber }), !acc.isEmpty {
                    acc[acc.count - 1] += s
                } else {
                    acc.append(s)
                }
            }
            if acc.count > 1, acc[0].count <= 1, !acc[0].contains(where: { $0.isNumber }) {
                acc[1] = acc[0] + acc[1]
                acc.removeFirst()
            }
            pieces.append(contentsOf: acc)
        }

        return pieces.filter { $0.count >= 2 }
    }

    private static func splitBy(_ re: NSRegularExpression, _ text: String) -> [String] {
        let ns = text as NSString
        var out: [String] = []
        var last = 0
        re.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let r = m?.range else { return }
            out.append(ns.substring(with: NSRange(location: last, length: max(0, r.location - last))))
            last = r.location + r.length
        }
        out.append(ns.substring(from: min(last, ns.length)))
        return out
    }

    private static func replace(_ re: NSRegularExpression, in text: String, with template: String) -> String {
        re.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: template,
        )
    }

    private static func clean(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: " ，。！？；、,.!?;:：~～"))
    }

    // MARK: 单条分析

    private static func analyze(_ raw: String, today: Date) -> TodoDraft? {
        var text = clean(raw)
        guard !text.isEmpty else { return nil }

        for p in prefixes where text.hasPrefix(p) {
            text = clean(String(text.dropFirst(p.count)))
            break
        }
        if text.isEmpty { return nil }

        let (due, stripped) = extractDue(text, today: today)
        // 日期词被抠掉后可能留下空格 / 悬空的「的」
        var title = clean(stripped).replacingOccurrences(of: " ", with: "")
        while title.hasPrefix("的") { title.removeFirst() }
        while title.hasSuffix("的") { title.removeLast() }
        // 只说了「明天」这种：标题退回原话（去掉口头语后的版本）
        if title.count < 2 { title = text }
        guard title.count >= 2 || title.contains(where: { $0.isNumber }) else { return nil }
        return TodoDraft(title: title, due: due)
    }

    // MARK: 日期

    /// 抽出「明天 / 下周三 / 3 天后 / 10月8号」等日期，并从标题里删掉这段。
    static func extractDue(_ text: String, today: Date) -> (Date?, String) {
        let cal = Calendar.current
        let base = cal.startOfDay(for: today)
        let ns = text as NSString

        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: base) ?? base }

        // 以周一为一周起点的第 weeksAhead 周的周 target（1=周日 … 7=周六）
        func weekday(_ target: Int, weeksAhead: Int) -> Date {
            let w = cal.component(.weekday, from: base)          // 1=周日
            let back = (w + 5) % 7                                // 周一=0 … 周日=6
            let weekStart = cal.date(byAdding: .day, value: -back, to: base) ?? base
            let offset = target == 1 ? 6 : target - 2
            var d = cal.date(byAdding: .day, value: offset + weeksAhead * 7, to: weekStart) ?? base
            if weeksAhead == 0, d < base { d = cal.date(byAdding: .day, value: 7, to: d) ?? d }
            return d
        }

        /// 相对本月偏移 offsetMonths 个月的 dayOfMonth 号
        func dateInMonth(offsetMonths: Int, dayOfMonth: Int) -> Date? {
            guard let firstOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: base)),
                  let target = cal.date(byAdding: .month, value: offsetMonths, to: firstOfThisMonth) else { return nil }
            return cal.date(byAdding: .day, value: dayOfMonth - 1, to: target)
        }

        /// 具体月份（如 10 月 8 号），跨年时取未来的那一年
        func monthDay(_ month: Int, _ dayOfMonth: Int) -> Date? {
            var comps = cal.dateComponents([.year, .month], from: base)
            comps.month = month
            comps.day = dayOfMonth
            guard let d = cal.date(from: comps) else { return nil }
            if d < base { return cal.date(byAdding: .year, value: 1, to: d) }
            return d
        }

        func cn(_ s: String) -> Int? {
            switch s {
            case "一", "1": return 2
            case "二", "2": return 3
            case "三", "3": return 4
            case "四", "4": return 5
            case "五", "5": return 6
            case "六", "6": return 7
            case "日", "天", "7": return 1
            default: return nil
            }
        }

        /// (正则, 由捕获组算出日期)
        let rules: [(String, (NSTextCheckingResult) -> Date?)] = [
            ("下下(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])", { m in cn(ns.substring(with: m.range(at: 1))).map { weekday($0, weeksAhead: 2) } }),
            ("下(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])", { m in cn(ns.substring(with: m.range(at: 1))).map { weekday($0, weeksAhead: 1) } }),
            ("(?:这|本)?(?:周|星期|礼拜)([一二三四五六日天1-7])", { m in cn(ns.substring(with: m.range(at: 1))).map { weekday($0, weeksAhead: 0) } }),
            ("(\\d{1,2})\\s*天(?:以)?后", { m in
                let n = Int(ns.substring(with: m.range(at: 1))) ?? 0
                return n > 0 && n <= 365 ? day(n) : nil
            }),
            ("下个?月(\\d{1,2})[号日]", { m in
                guard let d = Int(ns.substring(with: m.range(at: 1))), (1...31).contains(d) else { return nil }
                return dateInMonth(offsetMonths: 1, dayOfMonth: d)
            }),
            ("(\\d{1,2})月(\\d{1,2})[号日]?", { m in
                guard let mo = Int(ns.substring(with: m.range(at: 1))),
                      let d = Int(ns.substring(with: m.range(at: 2))),
                      (1...12).contains(mo), (1...31).contains(d) else { return nil }
                return monthDay(mo, d)
            }),
            ("(\\d{1,2})[号日]", { m in
                guard let d = Int(ns.substring(with: m.range(at: 1))), (1...31).contains(d) else { return nil }
                if let thisMonth = dateInMonth(offsetMonths: 0, dayOfMonth: d), thisMonth >= base {
                    return thisMonth
                }
                return dateInMonth(offsetMonths: 1, dayOfMonth: d)
            }),
            ("大后天", { _ in day(3) }),
            ("后天", { _ in day(2) }),
            ("明天|明日|明早|明晚", { _ in day(1) }),
            ("今天|今日|今晚", { _ in day(0) }),
        ]

        for (pattern, resolve) in rules {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
                  let due = resolve(m) else { continue }
            let rest = ns.replacingCharacters(in: m.range, with: "")
            return (due, rest)
        }
        return (nil, text)
    }
}
