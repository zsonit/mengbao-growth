import Foundation

// MARK: - 指标

enum GrowthMetric: String, CaseIterable, Identifiable {
    case height = "身高"
    case weight = "体重"
    case bmi = "BMI"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .height: return "cm"
        case .weight: return "kg"
        case .bmi: return ""
        }
    }

    var decimals: Int { self == .height ? 0 : 1 }
}

// MARK: - 评估等级

enum LevelTone: Equatable {
    case ok, warn, bad
}

struct GrowthLevel {
    let label: String
    let tone: LevelTone
    let desc: String
}

struct Evaluation {
    let months: Int
    var heightPercentile: Double?
    var weightPercentile: Double?
    var bmi: Double?
    var bmiPercentile: Double?
    var heightLevel: GrowthLevel?
    var bmiLevel: GrowthLevel?
    var source: String

    var isComplete: Bool { heightPercentile != nil && weightPercentile != nil }
}

// MARK: - 接种

struct Dose: Identifiable, Hashable {
    enum Status: String {
        case done, due, soon, pending, locked

        var label: String {
            switch self {
            case .done: return "已接种"
            case .due: return "已到期"
            case .soon: return "近期接种"
            case .pending: return "待接种"
            case .locked: return "已锁定"
            }
        }
    }

    var id: String { key }
    let key: String
    let months: Int
    let ageLabel: String
    let dueDate: Date
    let vaccine: Vaccine
    var status: Status
    var doneDate: Date?
}

// MARK: - 尺码

struct ShoeSize {
    var cn: Int?
    var eu: Int?
    var inner: Double?
    var top: String?
    var pant: String?
    var hip: String?
}

// MARK: - 生长计算

enum GrowthMath {

    static let zValues: [Double] = [-1.8808, -1.0364, 0, 1.0364, 1.8808]
    static let percentiles: [Double] = [3, 15, 50, 85, 97]

    // MARK: 日期与月龄

    static func ageMonths(from birth: Date, to date: Date = Date()) -> Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.month], from: cal.startOfDay(for: birth), to: cal.startOfDay(for: date))
        return max(0, comps.month ?? 0)
    }

    static func ageText(from birth: Date, to date: Date = Date()) -> String {
        let cal = Calendar.current
        let start = cal.startOfDay(for: birth)
        let end = cal.startOfDay(for: date)
        if end < start { return "未出生" }
        let c = cal.dateComponents([.year, .month, .day], from: start, to: end)
        let y = c.year ?? 0, m = c.month ?? 0, d = c.day ?? 0
        if y > 0 { return m > 0 ? "\(y) 岁 \(m) 个月" : "\(y) 岁" }
        if m > 0 { return d > 0 ? "\(m) 个月 \(d) 天" : "\(m) 个月" }
        return "\(d) 天"
    }

    static func daysToBirthday(_ birth: Date) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let b = cal.dateComponents([.month, .day], from: birth)
        var comps = DateComponents()
        comps.year = cal.component(.year, from: today)
        comps.month = b.month
        comps.day = b.day
        guard var next = cal.date(from: comps) else { return 0 }
        if next < today {
            comps.year = (comps.year ?? 0) + 1
            next = cal.date(from: comps) ?? next
        }
        return cal.dateComponents([.day], from: today, to: next).day ?? 0
    }

    // MARK: 插值

    static func interp(_ rows: [[Double]], _ x: Double, _ column: Int) -> Double {
        guard let first = rows.first, let last = rows.last else { return 0 }
        if x <= first[0] { return first[column] }
        if x >= last[0] { return last[column] }
        for i in 0..<(rows.count - 1) {
            let a = rows[i], b = rows[i + 1]
            if x >= a[0] && x <= b[0] {
                let span = b[0] - a[0]
                let t = span == 0 ? 0 : (x - a[0]) / span
                return a[column] + t * (b[column] - a[column])
            }
        }
        return last[column]
    }

    static func lmsRow(_ rows: [LMSRow], _ months: Double) -> LMSRow {
        guard let first = rows.first, let last = rows.last else {
            return LMSRow(months: months, l: 0, m: 1, s: 0.1)
        }
        if months <= first.months { return first }
        if months >= last.months { return last }
        for i in 0..<(rows.count - 1) {
            let a = rows[i], b = rows[i + 1]
            if months >= a.months && months <= b.months {
                let t = (months - a.months) / (b.months - a.months)
                return LMSRow(months: months,
                              l: a.l + t * (b.l - a.l),
                              m: a.m + t * (b.m - a.m),
                              s: a.s + t * (b.s - a.s))
            }
        }
        return last
    }

    static func value(atZ z: Double, row: LMSRow) -> Double {
        if abs(row.l) < 0.000001 { return row.m * exp(row.s * z) }
        let base = 1 + row.l * row.s * z
        if base <= 0 { return row.m }
        return row.m * pow(base, 1 / row.l)
    }

    // MARK: 误差函数（正态分布换算）

    static func erf(_ x: Double) -> Double {
        let sign = x < 0 ? -1.0 : 1.0
        let ax = abs(x)
        let p = 0.3275911
        let a1 = 0.254829592, a2 = -0.284496736, a3 = 1.421413741
        let a4 = -1.453152027, a5 = 1.061405429
        let t = 1 / (1 + p * ax)
        let y = 1 - ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * exp(-ax * ax)
        return sign * y
    }

    static func percentile(fromZ z: Double) -> Double {
        let p = 0.5 * (1 + erf(z / sqrt(2))) * 100
        return min(99.9, max(0.1, p))
    }

    // MARK: 参考带

    static func bmiMedian(sex: Sex, months: Double) -> Double {
        let h = lmsRow(sex == .boy ? Standards.boyLMSHeight : Standards.girlLMSHeight, min(max(months, 0), 60)).m
        let w = lmsRow(sex == .boy ? Standards.boyLMSWeight : Standards.girlLMSWeight, min(max(months, 0), 60)).m
        return w / pow(h / 100, 2)
    }

    /// BMI 判定标签：
    /// - <18 岁按同龄同性别百分位（WS/T 456 营养不良筛查思路）：偏瘦 <P15 · 正常 P15~P85 · 超重 P85~P95 · 肥胖 ≥P95
    /// - ≥18 岁按中国成人标准：偏瘦 <18.5 · 正常 18.5~23.9 · 超重 24.0~27.9 · 肥胖 ≥28
    /// 返回 nil 表示无法判定（缺 BMI 或缺百分位）
    static func bmiJudgeLabel(ageYears: Int, bmi: Double?, percentile: Double?) -> String? {
        guard let bmi, bmi > 0 else { return nil }
        if ageYears >= 18 {
            if bmi < 18.5 { return "偏瘦" }
            if bmi < 24 { return "正常" }
            if bmi < 28 { return "超重" }
            return "肥胖"
        }
        guard let p = percentile else { return nil }
        if p < 15 { return "偏瘦" }
        if p < 85 { return "正常" }
        if p < 95 { return "超重" }
        return "肥胖"
    }

    /// 判定标签对应的颜色基调
    static func bmiJudgeTone(_ label: String?) -> TagView.Tone {
        switch label {
        case "正常": return .ok
        case "超重": return .warn
        case "偏瘦", "肥胖": return .bad
        default: return .gray
        }
    }

    static func refBands(sex: Sex, metric: GrowthMetric, months: Int) -> [Double] {
        let m = Double(months)

        if months <= 60 {
            if metric == .bmi {
                let median = bmiMedian(sex: sex, months: m)
                let cv = 0.085 + 0.015 * min(1, m / 60)
                return zValues.map { median * (1 + cv * $0) }
            }
            let rows = metric == .height
                ? (sex == .boy ? Standards.boyLMSHeight : Standards.girlLMSHeight)
                : (sex == .boy ? Standards.boyLMSWeight : Standards.girlLMSWeight)
            let row = lmsRow(rows, m)
            return zValues.map { value(atZ: $0, row: row) }
        }

        if months <= 84 {
            switch metric {
            case .height:
                let median = interp(sex == .boy ? Standards.boyMedianHeight36_84 : Standards.girlMedianHeight36_84, m, 1)
                return zValues.map { median * (1 + 0.042 * $0) }
            case .weight:
                let median = interp(sex == .boy ? Standards.boyMedianWeight36_84 : Standards.girlMedianWeight36_84, m, 1)
                return zValues.map { median * (1 + 0.155 * $0) }
            case .bmi:
                let median = bmiMedian(sex: sex, months: 60)
                return zValues.map { median * (1 + 0.10 * $0) }
            }
        }

        let years = min(18, max(7, m / 12))
        switch metric {
        case .height:
            let rows = sex == .boy ? Standards.boyHeight7_18 : Standards.girlHeight7_18
            return (1...5).map { interp(rows, years, $0) }
        case .weight:
            let rows = sex == .boy ? Standards.boyWeight7_18 : Standards.girlWeight7_18
            let median = interp(rows, years, 1)
            let cv = 0.16 + 0.06 * min(1, max(0, (m - 84) / 132))
            return zValues.map { median * (1 + cv * $0) }
        case .bmi:
            let rows = sex == .boy ? Standards.boyBMI7_18 : Standards.girlBMI7_18
            let median = interp(rows, years, 1)
            let cv = 0.11 + 0.02 * min(1, max(0, (m - 84) / 132))
            return zValues.map { max(9, median * (1 + cv * $0)) }
        }
    }

    static func percentile(sex: Sex, metric: GrowthMetric, months: Int, value: Double) -> Double {
        let bands = refBands(sex: sex, metric: metric, months: months)
        if value <= bands[0] { return min(3, max(0.1, value / bands[0] * 3)) }
        if value >= bands[4] { return min(99.9, 97 + (value - bands[4]) / bands[4] * 30) }
        for i in 0..<4 {
            if value >= bands[i] && value <= bands[i + 1] {
                let span = bands[i + 1] - bands[i]
                let t = span == 0 ? 0 : (value - bands[i]) / span
                return percentiles[i] + t * (percentiles[i + 1] - percentiles[i])
            }
        }
        return 50
    }

    static func level(for percentile: Double) -> GrowthLevel {
        if percentile <= 3 {
            return GrowthLevel(label: "偏低", tone: .bad, desc: "处于同龄参考范围低位，建议到儿童保健科评估生长速度与营养状况。")
        }
        if percentile <= 15 {
            return GrowthLevel(label: "中下", tone: .warn, desc: "略低于同龄中位水平，属正常偏低区间，重点看生长速度是否稳定。")
        }
        if percentile <= 85 {
            return GrowthLevel(label: "中等", tone: .ok, desc: "处于同龄中位水平，属通常正常区间。")
        }
        if percentile <= 97 {
            return GrowthLevel(label: "中上", tone: .ok, desc: "高于同龄中位水平，属通常正常区间。")
        }
        return GrowthLevel(label: "偏高", tone: .warn, desc: "处于同龄参考范围高位，若伴随早发育迹象可咨询儿科。")
    }

    static func percentileLabel(_ p: Double) -> String {
        p < 1 ? String(format: "P%.1f", p) : "P\(Int(p.rounded()))"
    }

    static func bmiValue(height: Double, weight: Double) -> Double {
        guard height > 0 else { return 0 }
        return (weight / pow(height / 100, 2) * 10).rounded() / 10
    }

    // MARK: 单次评估

    static func evaluate(child: Child, record: GrowthRecord) -> Evaluation {
        let months = ageMonths(from: child.birthDate, to: record.date)
        var e = Evaluation(months: months,
                           heightPercentile: nil, weightPercentile: nil,
                           bmi: nil, bmiPercentile: nil,
                           heightLevel: nil, bmiLevel: nil,
                           source: months <= 60 ? "WHO 儿童生长标准（简化 LMS）"
                                   : (months <= 84 ? "中国 7 岁以下儿童生长发育参照标准" : "WS/T 423 身高发育等级评价"))

        if let h = record.height, h > 0 {
            let p = percentile(sex: child.sex, metric: .height, months: months, value: h)
            e.heightPercentile = p
            e.heightLevel = level(for: p)
        }
        if let w = record.weight, w > 0 {
            e.weightPercentile = percentile(sex: child.sex, metric: .weight, months: months, value: w)
        }
        if let h = record.height, let w = record.weight, h > 0, w > 0 {
            let bmi = bmiValue(height: h, weight: w)
            let p = percentile(sex: child.sex, metric: .bmi, months: months, value: bmi)
            e.bmi = bmi
            e.bmiPercentile = p
            e.bmiLevel = level(for: p)
        }
        return e
    }

    // MARK: 生长速度

    static func velocity(child: Child) -> (delta: Double, days: Int, perYear: Double)? {
        let recs = child.sortedRecords.filter { $0.height != nil }
        guard recs.count >= 2 else { return nil }
        let last = recs[recs.count - 1], prev = recs[recs.count - 2]
        guard let h1 = last.height, let h2 = prev.height else { return nil }
        let days = Calendar.current.dateComponents([.day], from: prev.date, to: last.date).day ?? 0
        guard days >= 20 else { return nil }
        return (h1 - h2, days, (h1 - h2) / Double(days) * 365)
    }

    static func velocityComment(child: Child, perYear: Double) -> String {
        let months = ageMonths(from: child.birthDate)
        let baseline: Double = months < 12 ? 12 : (months < 36 ? 7 : (months < 60 ? 5 : (months < 120 ? 4 : 3)))
        if perYear < baseline * 0.6 { return "偏慢，建议关注" }
        if perYear > baseline * 2.2 { return "偏快，注意记录" }
        return "正常范围"
    }

    // MARK: 身高预测

    static func predictedHeight(child: Child, record: GrowthRecord, settings: AppSettings) -> (value: Double, low: Double, high: Double, method: String)? {
        guard let h = record.height, h > 0 else { return nil }
        if let f = settings.fatherHeight, let m = settings.motherHeight, f > 0, m > 0 {
            let target = child.sex == .girl ? (f + m - 13) / 2 : (f + m + 13) / 2
            return (target, target - 5, target + 5, "靶身高法（父母身高）")
        }
        let months = ageMonths(from: child.birthDate, to: record.date)
        let p = percentile(sex: child.sex, metric: .height, months: months, value: h)
        let adult = refBands(sex: child.sex, metric: .height, months: 216)
        var base = adult[2]
        if p < 15 { base = adult[0] + (adult[1] - adult[0]) * (p - 3) / 12 }
        else if p < 50 { base = adult[1] + (adult[2] - adult[1]) * (p - 15) / 35 }
        else if p < 85 { base = adult[2] + (adult[3] - adult[2]) * (p - 50) / 35 }
        else { base = adult[3] + (adult[4] - adult[3]) * (p - 85) / 12 }
        return (base, base - 5, base + 5, "当前百分位外推（未填父母身高）")
    }

    // MARK: 接种计划

    static var totalDoses: Int {
        Standards.vaccineByAge.values.reduce(0) { $0 + $1.count }
    }

    static func schedule(for child: Child) -> [Dose] {
        let cal = Calendar.current
        let currentMonths = ageMonths(from: child.birthDate)
        var list: [Dose] = []
        // 程序表剂次调整后的旧记录兼容：老 key 打过勾的自动迁移到新 key
        let legacyKeys: [String: [String]] = [
            "6|DTaP|第 3 剂": ["6|DTaP|第 4 剂", "5|DTaP|第 3 剂"],
            "72|DT|第 5 剂": ["72|DTaP|第 5 剂"],
        ]
        for (label, months) in Standards.vaccineAges {
            guard let dueDate = cal.date(byAdding: .month, value: months, to: child.birthDate) else { continue }
            for v in (Standards.vaccineByAge[months] ?? []) {
                let key = "\(months)|\(v.code)|\(v.dose)"
                var done = child.shots[key]
                if done == nil, let legacy = legacyKeys[key] {
                    done = legacy.lazy.compactMap { child.shots[$0] }.first
                }
                var status: Dose.Status = .pending
                if done != nil {
                    status = .done
                } else if months <= currentMonths {
                    status = .due
                } else if months - currentMonths <= 2 {
                    status = .soon
                }
                list.append(Dose(key: key, months: months, ageLabel: label, dueDate: dueDate,
                                 vaccine: v, status: status, doneDate: done?.date))
            }
        }

        // 自选（自费）疫苗：勾选后并入同一份日程，key 以 "opt|" 开头便于区分
        for oid in (child.optVaccines ?? []) {
            guard let opt = Standards.optionalById[oid] else { continue }
            for (idx, months) in opt.months.enumerated() {
                guard let dueDate = cal.date(byAdding: .month, value: months, to: child.birthDate) else { continue }
                let key = "opt|\(oid)|\(idx)|\(months)"
                let done = child.shots[key]
                var status: Dose.Status = .pending
                if done != nil {
                    status = .done
                } else if months <= currentMonths {
                    status = .due
                } else if months - currentMonths <= 2 {
                    status = .soon
                }
                let oral = opt.name.contains("口服")
                let vaccine = Vaccine(
                    code: "OPT-\(oid.uppercased())",
                    name: opt.name,
                    dose: "第 \(idx + 1) 剂 / 共 \(opt.months.count) 剂",
                    route: oral ? "口服" : "肌内注射",
                    site: oral ? "口服（接种前 30 分钟避免喂奶）" : "上臂外侧三角肌 / 大腿前外侧",
                    note: "\(opt.desc)。自费疫苗，参考价 \(opt.price)。是否接种请与接种医生沟通。"
                )
                list.append(Dose(key: key, months: months, ageLabel: ageText(for: months),
                                 dueDate: dueDate, vaccine: vaccine, status: status, doneDate: done?.date))
            }
        }

        // 13 岁女生免费 HPV（双价，两剂间隔 6 个月；男生不排）
        if child.sex == .girl {
            for (idx, months) in [156, 162].enumerated() {
                guard let dueDate = cal.date(byAdding: .month, value: months, to: child.birthDate) else { continue }
                let key = "\(months)|HPV2|第 \(idx + 1) 剂"
                let done = child.shots[key]
                var status: Dose.Status = .pending
                if done != nil {
                    status = .done
                } else if months <= currentMonths {
                    status = .due
                } else if months - currentMonths <= 2 {
                    status = .soon
                }
                let vaccine = Vaccine(
                    code: "HPV2",
                    name: "双价人乳头瘤病毒疫苗",
                    dose: "第 \(idx + 1) 剂",
                    route: "肌内注射",
                    site: "上臂外侧三角肌",
                    note: idx == 0
                        ? "适龄女生免费接种（以当地政策为准）；两剂间隔 6 个月，既往已完成 HPV 全程接种者无需重复接种。"
                        : "第 2 剂与第 1 剂间隔 6 个月。"
                )
                list.append(Dose(key: key, months: months, ageLabel: ageText(for: months),
                                 dueDate: dueDate, vaccine: vaccine, status: status, doneDate: done?.date))
            }
        }

        // 减毒活 / 灭活「二选一」：接种其一后，组内另一种自动锁定（红字提示，不能再打勾）
        let doneCodes = Set(child.shots.keys.compactMap { key -> String? in
            let parts = key.split(separator: "|")
            return parts.count >= 2 ? String(parts[1]) : nil
        })
        list = list.map { dose in
            guard dose.status != .done, let group = Standards.altGroup(of: dose.vaccine.code) else { return dose }
            let rivals = (Standards.altGroups[group] ?? []).filter { $0 != dose.vaccine.code }
            if rivals.contains(where: { doneCodes.contains($0) }) {
                return Dose(key: dose.key, months: dose.months, ageLabel: dose.ageLabel,
                            dueDate: dose.dueDate, vaccine: dose.vaccine, status: .locked, doneDate: nil)
            }
            return dose
        }
        return list
    }

    /// 月龄 -> 中文年龄提示（自选疫苗的月龄不一定在标准表里）
    static func ageText(for months: Int) -> String {
        if let hit = Standards.vaccineAges.first(where: { $0.1 == months }) { return hit.0 }
        if months < 12 { return "\(months) 月龄" }
        let y = months / 12, m = months % 12
        return m == 0 ? "\(y) 岁" : "\(y) 岁 \(m) 个月"
    }

    static func doneCount(for child: Child) -> Int {
        schedule(for: child).filter { $0.status == .done }.count
    }

    // MARK: 尺码

    static func shoeSize(foot: Double?, height: Double?) -> ShoeSize {
        var s = ShoeSize()
        if let f = foot, f > 0 {
            s.cn = Int((f * 2 - 10).rounded())
            s.eu = Int((f * 1.5 + 2).rounded())
            s.inner = ((f + 0.8) * 10).rounded() / 10
        }
        if let h = height, h > 0 {
            let size = (h / 10).rounded() * 10
            s.top = "\(Int(size)) 码"
            s.pant = "\(Int(size)) 码"
            s.hip = "\(Int((h * 0.62).rounded())) cm 裤长"
        }
        return s
    }

    // MARK: 阶段重点

    static func milestones(for child: Child) -> [String] {
        let months = ageMonths(from: child.birthDate)
        if let hit = Standards.milestones.first(where: { months <= $0.maxMonth }) {
            return hit.items
        }
        return Standards.milestones.last?.items ?? []
    }

    static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日"
        return f.string(from: date)
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }
}
