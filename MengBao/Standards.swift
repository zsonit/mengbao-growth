import Foundation

// MARK: - 参考数据（只放数据，方便日后替换权威数据源）

struct LMSRow {
    let months: Double
    let l: Double
    let m: Double
    let s: Double
}

struct Vaccine: Hashable, Codable {
    let code: String
    let name: String
    let dose: String
    let route: String
    let site: String
    let note: String
}

struct Clinic: Identifiable, Hashable, Codable {
    var id: String { "\(name)@\(String(format: "%.4f", lat)),\(String(format: "%.4f", lng))" }
    let name: String
    let city: String
    let district: String
    let address: String
    let phone: String
    let hours: String
    let vaccines: String
    let note: String
    let tag: String
    let scope: String
    let lat: Double
    let lng: Double
    let star: Bool
}

enum Standards {

    static let disclaimer = "所有评估结果仅用于家庭记录与趋势观察，不构成医疗诊断。发现生长明显偏离，请到儿科或儿童保健科就诊。"

    // MARK: 0–5 岁 WHO 简化 LMS

    static let boyLMSHeight: [LMSRow] = [
        LMSRow(months: 0, l: 0.3333, m: 49.1477, s: 1.8903),
        LMSRow(months: 3, l: 0.3333, m: 57.0678, s: 1.7793),
        LMSRow(months: 6, l: 0.3333, m: 64.4186, s: 1.7640),
        LMSRow(months: 9, l: 0.3333, m: 69.9543, s: 1.7678),
        LMSRow(months: 12, l: 0.3333, m: 74.6633, s: 1.7886),
        LMSRow(months: 18, l: 0.3333, m: 82.6227, s: 1.8281),
        LMSRow(months: 24, l: 0.3333, m: 88.9776, s: 1.8720),
        LMSRow(months: 36, l: 0.3333, m: 97.0267, s: 1.9779),
        LMSRow(months: 48, l: 0.3333, m: 103.9739, s: 2.0615),
        LMSRow(months: 60, l: 0.3333, m: 110.4595, s: 2.1357)
    ]

    static let boyLMSWeight: [LMSRow] = [
        LMSRow(months: 0, l: 0.3514, m: 3.4727, s: 0.9318),
        LMSRow(months: 3, l: 0.3514, m: 5.6918, s: 0.9207),
        LMSRow(months: 6, l: 0.3514, m: 7.7275, s: 0.9120),
        LMSRow(months: 9, l: 0.3514, m: 9.2614, s: 0.9075),
        LMSRow(months: 12, l: 0.3514, m: 10.5302, s: 0.9050),
        LMSRow(months: 18, l: 0.3514, m: 12.3639, s: 0.9029),
        LMSRow(months: 24, l: 0.3514, m: 13.9500, s: 0.9021),
        LMSRow(months: 36, l: 0.3514, m: 16.2000, s: 0.9024),
        LMSRow(months: 48, l: 0.3514, m: 18.1871, s: 0.9032),
        LMSRow(months: 60, l: 0.3514, m: 20.0844, s: 0.9050)
    ]

    static let girlLMSHeight: [LMSRow] = [
        LMSRow(months: 0, l: 0.3333, m: 48.5425, s: 1.9179),
        LMSRow(months: 3, l: 0.3333, m: 56.2713, s: 1.7910),
        LMSRow(months: 6, l: 0.3333, m: 63.4948, s: 1.7696),
        LMSRow(months: 9, l: 0.3333, m: 69.0279, s: 1.7669),
        LMSRow(months: 12, l: 0.3333, m: 73.7118, s: 1.7886),
        LMSRow(months: 18, l: 0.3333, m: 81.2519, s: 1.8162),
        LMSRow(months: 24, l: 0.3333, m: 87.4042, s: 1.8496),
        LMSRow(months: 36, l: 0.3333, m: 95.3676, s: 1.9470),
        LMSRow(months: 48, l: 0.3333, m: 102.2184, s: 2.0254),
        LMSRow(months: 60, l: 0.3333, m: 108.8906, s: 2.0915)
    ]

    static let girlLMSWeight: [LMSRow] = [
        LMSRow(months: 0, l: 0.3509, m: 3.3982, s: 0.9398),
        LMSRow(months: 3, l: 0.3509, m: 5.3289, s: 0.9262),
        LMSRow(months: 6, l: 0.3509, m: 7.1574, s: 0.9158),
        LMSRow(months: 9, l: 0.3509, m: 8.5573, s: 0.9105),
        LMSRow(months: 12, l: 0.3509, m: 9.7174, s: 0.9074),
        LMSRow(months: 18, l: 0.3509, m: 11.2468, s: 0.9047),
        LMSRow(months: 24, l: 0.3509, m: 12.5960, s: 0.9033),
        LMSRow(months: 36, l: 0.3509, m: 14.6100, s: 0.9029),
        LMSRow(months: 48, l: 0.3509, m: 16.4040, s: 0.9038),
        LMSRow(months: 60, l: 0.3509, m: 18.0870, s: 0.9064)
    ]

    // MARK: 3–7 岁中位数（中国 7 岁以下儿童生长发育参照标准）

    static let boyMedianHeight36_84: [[Double]] = [
        [36, 95.9], [42, 103.2], [48, 109.7], [54, 115.7], [60, 121.2],
        [66, 126.5], [72, 131.7], [78, 137.0], [84, 142.4]
    ]

    static let boyMedianWeight36_84: [[Double]] = [
        [36, 15.87], [42, 18.22], [48, 20.74], [54, 23.27], [60, 26.14],
        [66, 29.38], [72, 32.99], [78, 36.96], [84, 41.22]
    ]

    static let girlMedianHeight36_84: [[Double]] = [
        [36, 95.3], [42, 102.3], [48, 108.6], [54, 114.7], [60, 120.1],
        [66, 125.4], [72, 130.7], [78, 136.1], [84, 141.6]
    ]

    static let girlMedianWeight36_84: [[Double]] = [
        [36, 14.88], [42, 16.94], [48, 19.30], [54, 21.81], [60, 24.72],
        [66, 28.03], [72, 31.66], [78, 35.63], [84, 39.98]
    ]

    // MARK: 7–18 岁 [岁, P3, P15, P50, P85, P97]

    static let boyHeight7_18: [[Double]] = [
        [7, 112.3, 117.9, 124.0, 130.1, 135.8],
        [8, 116.3, 122.5, 130.0, 137.5, 143.8],
        [9, 121.0, 127.8, 135.4, 143.0, 149.8],
        [10, 125.5, 133.0, 140.2, 147.4, 154.2],
        [11, 130.0, 138.2, 145.3, 152.4, 159.5],
        [12, 135.3, 144.1, 151.9, 159.7, 167.0],
        [13, 142.3, 151.9, 159.5, 167.1, 174.1],
        [14, 148.2, 158.2, 165.9, 173.6, 180.7],
        [15, 151.7, 161.8, 169.8, 177.8, 185.0],
        [16, 153.6, 163.8, 171.6, 179.6, 187.0],
        [17, 154.8, 164.9, 172.3, 180.3, 187.7],
        [18, 155.8, 165.6, 172.7, 180.7, 188.2]
    ]

    static let girlHeight7_18: [[Double]] = [
        [7, 111.2, 116.6, 122.5, 128.4, 134.0],
        [8, 115.4, 121.6, 128.5, 135.4, 141.8],
        [9, 120.3, 127.2, 134.1, 141.0, 147.4],
        [10, 125.2, 132.8, 140.1, 147.4, 154.2],
        [11, 130.7, 139.1, 146.6, 154.1, 161.2],
        [12, 136.5, 145.3, 152.4, 159.5, 166.6],
        [13, 142.2, 150.7, 156.3, 161.9, 167.5],
        [14, 146.1, 153.6, 158.6, 163.6, 168.6],
        [15, 147.6, 154.9, 159.8, 165.2, 170.7],
        [16, 148.3, 155.6, 160.1, 165.6, 171.2],
        [17, 148.9, 156.2, 160.3, 165.8, 171.4],
        [18, 149.5, 156.8, 160.6, 166.1, 171.7]
    ]

    static let boyWeight7_18: [[Double]] = [
        [7, 24.06], [8, 27.33], [9, 30.46], [10, 33.74], [11, 37.69], [12, 42.49],
        [13, 48.08], [14, 53.37], [15, 57.72], [16, 61.40], [17, 64.30], [18, 66.50]
    ]

    static let girlWeight7_18: [[Double]] = [
        [7, 22.94], [8, 25.84], [9, 28.77], [10, 31.97], [11, 36.10], [12, 41.02],
        [13, 46.61], [14, 51.41], [15, 55.65], [16, 58.88], [17, 61.32], [18, 62.90]
    ]

    static let boyBMI7_18: [[Double]] = [
        [7, 17.4], [8, 17.8], [9, 18.2], [10, 18.7], [11, 19.4], [12, 20.3],
        [13, 21.2], [14, 22.1], [15, 22.8], [16, 23.3], [17, 23.8], [18, 24.2]
    ]

    static let girlBMI7_18: [[Double]] = [
        [7, 17.2], [8, 17.6], [9, 18.1], [10, 18.7], [11, 19.6], [12, 20.5],
        [13, 21.4], [14, 22.2], [15, 22.8], [16, 23.3], [17, 23.7], [18, 24.1]
    ]

    // MARK: 免疫规划程序（2026 版为内置基线，支持每年远程自动更新）

    /// 内置程序表版本年：国家发布新版程序表后，随仓库 vaccine-schedule.json 更新，App 内自动拉取应用
    static let builtinScheduleYear = 2026

    private static let builtinAges: [(String, Int)] = [
        ("出生时", 0), ("1 月龄", 1), ("2 月龄", 2), ("3 月龄", 3), ("4 月龄", 4),
        ("5 月龄", 5), ("6 月龄", 6), ("8 月龄", 8), ("9 月龄", 9), ("18 月龄", 18),
        ("2 岁", 24), ("3 岁", 36), ("4 岁", 48), ("6 岁", 72)
    ]

    private static let builtinByAge: [Int: [Vaccine]] = [
        0: [Vaccine(code: "HepB", name: "乙肝疫苗", dose: "第 1 剂", route: "肌内注射", site: "上臂外侧三角肌",
                   note: "出生 12 小时内完成；母亲 HBsAg 阳性或不详者应尽早接种，并加注乙肝免疫球蛋白。")],
        1: [Vaccine(code: "HepB", name: "乙肝疫苗", dose: "第 2 剂", route: "肌内注射", site: "上臂外侧三角肌",
                   note: "与第 1 剂间隔 ≥ 28 天。")],
        2: [
            Vaccine(code: "IPV", name: "脊灰灭活疫苗", dose: "第 1 剂", route: "肌内注射", site: "大腿前外侧中部",
                    note: "与下一剂间隔 ≥ 28 天。"),
            Vaccine(code: "DTaP", name: "百白破疫苗", dose: "第 1 剂", route: "肌内注射", site: "上臂外侧三角肌 / 大腿前外侧",
                    note: "2026 年 1 月 1 日起调整为 2、4、6、18 月龄及 6 岁共 5 剂。")
        ],
        3: [Vaccine(code: "IPV", name: "脊灰灭活疫苗", dose: "第 2 剂", route: "肌内注射", site: "大腿前外侧中部",
                   note: "若后续选择五联疫苗，可替代本剂与百白破。")],
        4: [
            Vaccine(code: "bOPV", name: "脊灰减毒活疫苗", dose: "第 3 剂", route: "口服", site: "口服",
                    note: "与前一剂脊灰疫苗间隔 ≥ 28 天。"),
            Vaccine(code: "DTaP", name: "百白破疫苗", dose: "第 2 剂", route: "肌内注射", site: "上臂外侧三角肌",
                    note: "各剂间隔 4–8 周。")
        ],
        5: [Vaccine(code: "DTaP", name: "百白破疫苗", dose: "第 3 剂", route: "肌内注射", site: "上臂外侧三角肌",
                   note: "基础免疫 3 剂完成。")],
        6: [
            Vaccine(code: "HepB", name: "乙肝疫苗", dose: "第 3 剂", route: "肌内注射", site: "上臂外侧三角肌",
                    note: "3 剂全程完成。"),
            Vaccine(code: "DTaP", name: "百白破疫苗", dose: "第 4 剂", route: "肌内注射", site: "上臂外侧三角肌",
                    note: "与前一剂间隔 ≥ 6 个月。"),
            Vaccine(code: "MPV-A", name: "A 群流脑多糖疫苗", dose: "第 1 剂", route: "皮下注射", site: "上臂外侧三角肌附着处",
                    note: "与第 2 剂间隔 ≥ 3 个月。")
        ],
        8: [
            Vaccine(code: "MMR", name: "麻腮风疫苗", dose: "第 1 剂", route: "皮下注射", site: "上臂外侧三角肌附着处",
                    note: "2020 年 6 月起取消麻风疫苗，统一使用麻腮风。"),
            Vaccine(code: "JE-L", name: "乙脑减毒活疫苗", dose: "第 1 剂", route: "皮下注射", site: "上臂外侧三角肌下缘",
                    note: "与乙脑灭活疫苗二选一；若选灭活则需 4 剂。")
        ],
        9: [Vaccine(code: "MPV-A", name: "A 群流脑多糖疫苗", dose: "第 2 剂", route: "皮下注射", site: "上臂外侧三角肌附着处",
                   note: "完成 A 群流脑基础免疫。")],
        18: [
            Vaccine(code: "DTaP", name: "百白破疫苗", dose: "第 4 剂", route: "肌内注射", site: "上臂外侧三角肌",
                    note: "基础免疫后加强 1 剂（2026 版由第 5 剂调整为第 4 剂）。"),
            Vaccine(code: "MMR", name: "麻腮风疫苗", dose: "第 2 剂", route: "皮下注射", site: "上臂外侧三角肌附着处",
                    note: "两剂麻腮风完成。"),
            Vaccine(code: "HepA-L", name: "甲肝减毒活疫苗", dose: "第 1 剂", route: "皮下注射", site: "上臂外侧三角肌附着处",
                    note: "与甲肝灭活疫苗二选一，减毒活疫苗只需 1 剂。")
        ],
        24: [
            Vaccine(code: "JE-L", name: "乙脑减毒活疫苗", dose: "第 2 剂", route: "皮下注射", site: "上臂外侧三角肌下缘",
                    note: "减毒活疫苗全程 2 剂完成。"),
            Vaccine(code: "HepA-I", name: "甲肝灭活疫苗", dose: "第 2 剂", route: "肌内注射", site: "上臂外侧三角肌",
                    note: "若 18 月龄选择灭活疫苗则需此剂，两剂间隔 ≥ 6 个月。")
        ],
        36: [Vaccine(code: "MPV-AC", name: "A 群 C 群流脑多糖疫苗", dose: "第 1 剂", route: "皮下注射", site: "上臂外侧三角肌附着处",
                    note: "满 3 岁起接种，与 A 群流脑最后一剂间隔 ≥ 1 年。")],
        48: [Vaccine(code: "bOPV", name: "脊灰减毒活疫苗", dose: "第 4 剂", route: "口服", site: "口服",
                    note: "完成脊灰 4 剂全程。已打满 4 剂含 IPV 成分疫苗（如五联）者 4 岁不需再打。")],
        72: [
            Vaccine(code: "DTaP", name: "百白破疫苗", dose: "第 5 剂", route: "肌内注射", site: "上臂外侧三角肌",
                    note: "2026 年起 6 岁由白破改为百白破。"),
            Vaccine(code: "MPV-AC", name: "A 群 C 群流脑多糖疫苗", dose: "第 2 剂", route: "皮下注射", site: "上臂外侧三角肌附着处",
                    note: "完成流脑全程，小学入学前查验。")
        ]
    ]

    // MARK: 程序表动态层（每年自动更新）

    private static let schedLock = NSLock()
    private static let schedJSONKey = "vaccineScheduleJSON"
    private static let schedCheckYearKey = "vaccineScheduleCheckYear"
    private static var cachedAges: [(String, Int)] = builtinAges
    private static var cachedByAge: [Int: [Vaccine]] = builtinByAge
    private static var cachedYear: Int = builtinScheduleYear

    /// 当前生效的程序表版本年
    static var scheduleYear: Int {
        schedLock.lock(); defer { schedLock.unlock() }
        return cachedYear
    }

    /// 当前生效的接种程序（有远程更新版则用远程，否则内置）
    static var vaccineAges: [(String, Int)] {
        schedLock.lock(); defer { schedLock.unlock() }
        return cachedAges
    }

    static var vaccineByAge: [Int: [Vaccine]] {
        schedLock.lock(); defer { schedLock.unlock() }
        return cachedByAge
    }

    /// 启动时调用：应用上次拉取到的远程程序表 + 每年首次启动时检查一次更新
    static func bootScheduleSync() {
        schedLock.lock()
        if let s = UserDefaults.standard.string(forKey: schedJSONKey), let data = s.data(using: .utf8) {
            applyRemote(data, locked: true)
        }
        schedLock.unlock()
        checkRemoteSchedule()
    }

    /// 每年只发一次请求；国家发布新版程序表后，把新 JSON 推到仓库即可全量自动更新
    static func checkRemoteSchedule() {
        let year = Calendar.current.component(.year, from: Date())
        let d = UserDefaults.standard
        guard d.integer(forKey: schedCheckYearKey) < year, scheduleYear < year || d.integer(forKey: schedCheckYearKey) == 0 else {
            d.set(year, forKey: schedCheckYearKey)
            return
        }
        d.set(year, forKey: schedCheckYearKey)
        let url = URL(string: "https://cdn.jsdelivr.net/gh/zsonit/mengbao-growth@main/vaccine-schedule.json")!
        URLSession.shared.dataTask(with: url) { data, resp, err in
            guard err == nil,
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let data else { return }
            if let applied = applyRemote(data, locked: false) {
                AppLog.i("Vaccine", "接种程序表已自动更新至 \(applied) 年版")
            }
        }.resume()
    }

    /// 解析并应用远程程序表；仅在版本更新时生效，返回新版本年
    @discardableResult
    private static func applyRemote(_ data: Data, locked: Bool) -> Int? {
        struct Remote: Decodable {
            struct Age: Decodable { let label: String; let months: Int }
            let year: Int
            let ages: [Age]
            let byAge: [String: [Vaccine]]
        }
        guard let r = try? JSONDecoder().decode(Remote.self, from: data) else { return nil }
        if !locked { schedLock.lock() }
        defer { if !locked { schedLock.unlock() } }
        guard r.year > cachedYear else { return nil }
        cachedAges = r.ages.map { ($0.label, $0.months) }
        cachedByAge = Dictionary(uniqueKeysWithValues: r.byAge.map { (Int($0.key) ?? -1, $0.value) })
        cachedYear = r.year
        UserDefaults.standard.set(String(data: data, encoding: .utf8), forKey: schedJSONKey)
        return r.year
    }

    /// 自选（自费 / 非免疫规划）疫苗目录：勾选后自动加进接种日程
    struct OptionalVaccine: Identifiable, Hashable {
        let id: String
        let name: String
        let price: String            // 「¥460 ~ 800/剂 × 4剂」
        let desc: String
        let months: [Int]            // 每一剂的月龄
    }

    static let optionalCatalog: [OptionalVaccine] = [
        OptionalVaccine(id: "pcv13", name: "13 价肺炎结合疫苗", price: "¥460 ~ 800/剂 × 4 剂",
                        desc: "肺炎球菌引起的肺炎、脑膜炎、中耳炎和败血症等",
                        months: [2, 4, 6, 15]),
        OptionalVaccine(id: "pentax", name: "五联疫苗", price: "¥600 ~ 640/剂 × 4 剂",
                        desc: "替代百白破、白喉、破伤风、脊髓灰质炎、b 型流感嗜血杆菌（Hib）",
                        months: [2, 3, 4, 18]),
        OptionalVaccine(id: "rota5", name: "口服五价轮状病毒疫苗", price: "¥280 ~ 320/剂 × 3 剂",
                        desc: "轮状病毒引起的严重腹泻、呕吐、脱水（秋季腹泻）",
                        months: [2, 3, 4]),
        OptionalVaccine(id: "rota6", name: "口服六价轮状病毒疫苗", price: "¥298 ~ 307/剂 × 3 剂",
                        desc: "相比五价多覆盖一个 G9 型",
                        months: [2, 4, 6]),
        OptionalVaccine(id: "mcv4", name: "ACYW135 群流脑疫苗", price: "¥420/剂 × 4 剂",
                        desc: "A、C、Y、W135 群脑膜炎奈瑟菌引起的流脑，替代 A 群多糖和 A+C 群多糖",
                        months: [6, 7, 36, 72]),
        OptionalVaccine(id: "varicella", name: "水痘疫苗", price: "¥160 ~ 200/剂 × 2 剂",
                        desc: "水痘及水痘带状疱疹病毒感染",
                        months: [12, 48]),
        OptionalVaccine(id: "ev71", name: "EV71 手足口疫苗", price: "¥180 ~ 220/剂 × 2 剂",
                        desc: "EV71 型肠道病毒引起的重症手足口病，6 月龄 ~ 5 岁接种",
                        months: [6, 7]),
        OptionalVaccine(id: "hib", name: "Hib 疫苗", price: "¥120 ~ 160/剂 × 4 剂",
                        desc: "b 型流感嗜血杆菌引起的肺炎、脑膜炎等",
                        months: [2, 3, 4, 18]),
        OptionalVaccine(id: "hpv", name: "HPV 疫苗", price: "¥330 ~ 1300/剂 × 2 剂",
                        desc: "9 ~ 14 岁女生优先，2 剂程序，预防宫颈癌",
                        months: [108, 114])
    ]

    static let optionalById: [String: OptionalVaccine] =
        Dictionary(uniqueKeysWithValues: optionalCatalog.map { ($0.id, $0) })

    // MARK: 疫苗补充信息（预防疾病 / 每剂剂量）与「二选一」分组

    /// code -> (预防什么, 每剂剂量)；展示用，不在程序表里重复写
    static let extraByCode: [String: (prevents: String, amount: String)] = [
        "HepB":   ("乙型肝炎", "0.5 ml"),
        "IPV":    ("脊髓灰质炎", "0.5 ml"),
        "bOPV":   ("脊髓灰质炎", "口服 2 滴"),
        "DTaP":   ("百日咳、白喉、破伤风", "0.5 ml"),
        "MMR":    ("麻疹、流行性腮腺炎、风疹", "0.5 ml"),
        "JE-L":   ("流行性乙型脑炎", "0.5 ml"),
        "JE-I":   ("流行性乙型脑炎", "0.5 ml"),
        "MPV-A":  ("流行性脑脊髓膜炎（A 群）", "0.5 ml"),
        "MPV-AC": ("流行性脑脊髓膜炎（A 群、C 群）", "0.5 ml"),
        "HepA-L": ("甲型肝炎", "0.5 ml"),
        "HepA-I": ("甲型肝炎", "0.5 ml"),
    ]

    /// 减毒活疫苗 / 灭活疫苗「二选一」组：接种其一后，组内另一种自动锁定
    static let altGroups: [String: [String]] = [
        "JE":   ["JE-L", "JE-I"],
        "HepA": ["HepA-L", "HepA-I"],
    ]

    /// code -> 所属二选一组名（不在组内返回 nil）
    static func altGroup(of code: String) -> String? {
        altGroups.first(where: { $0.value.contains(code) })?.key
    }

    /// code 的中文名（用于锁定提示）
    static let altLabel: [String: String] = [
        "JE-L": "乙脑减毒活疫苗", "JE-I": "乙脑灭活疫苗",
        "HepA-L": "甲肝减毒活疫苗", "HepA-I": "甲肝灭活疫苗",
    ]

    static let optionalVaccines: [(String, String)] = [
        ("五联疫苗", "2 / 3 / 4 月龄 + 18 月龄"),
        ("13 价肺炎", "2 / 4 / 6 月龄 + 12–15 月龄"),
        ("轮状病毒", "6 周龄起口服，3 剂"),
        ("EV71 手足口", "6 月龄–5 岁，2 剂"),
        ("水痘", "12 月龄 + 4–6 岁"),
        ("流感疫苗", "6 月龄以上每年秋季"),
        ("Hib", "2 / 3 / 4 月龄 + 18 月龄"),
        ("HPV", "9–14 岁女生优先，2 剂")
    ]

    static let scopeMap: [Character: String] = [
        "①": "儿童免疫规划",
        "②": "卡介苗 / 乙肝首针",
        "③": "狂犬病疫苗",
        "④": "非免疫规划（自费）"
    ]

    // MARK: 接种门诊（离线示例数据）

    static let clinics: [Clinic] = [
        Clinic(name: "广州市天河区妇幼保健院预防接种门诊", city: "广州", district: "天河区", address: "天河区天河北路 367 号", phone: "020-38809120", hours: "周一至周六 8:00-11:30 14:00-17:00", vaccines: "乙肝、脊灰、百白破、麻腮风、流脑、乙脑、甲肝、水痘、流感", note: "支持「粤苗」预约，每日放号", tag: "省属示范门诊", scope: "①②③④", lat: 23.1416, lng: 113.3245, star: true),
        Clinic(name: "天河区员村街社区卫生服务中心", city: "广州", district: "天河区", address: "天河区员村二横路员村街 26 号", phone: "020-85535670", hours: "周二至周六 8:00-11:30", vaccines: "免疫规划疫苗 + 水痘、手足口、流感", note: "人流量较大，建议线上取号", tag: "社区门诊", scope: "①③④", lat: 23.1085, lng: 113.3558, star: false),
        Clinic(name: "天河区石牌街华师社区卫生服务中心", city: "广州", district: "天河区", address: "天河区中山大道西 55 号华南师范大学内", phone: "020-85211020", hours: "周三至周六 8:00-11:30", vaccines: "儿童免疫规划疫苗", note: "校内师生及辖区儿童", tag: "校园门诊", scope: "①③④", lat: 23.1391, lng: 113.3544, star: false),
        Clinic(name: "广州市妇女儿童医疗中心（珠江新城）预防接种特需门诊", city: "广州", district: "天河区", address: "天河区金穗路 9 号", phone: "020-81886332", hours: "周一至周日 8:00-12:00 14:00-17:00", vaccines: "全部免疫规划疫苗、卡介苗、自费二类疫苗齐全", note: "特需门诊需自费挂号", tag: "三甲医院", scope: "①②③④", lat: 23.1208, lng: 113.3250, star: true),
        Clinic(name: "越秀区北京街社区卫生服务中心", city: "广州", district: "越秀区", address: "越秀区惠福东路 472 号", phone: "020-83332858", hours: "周一至周六 8:00-11:30", vaccines: "免疫规划疫苗 + 水痘、流感、肺炎", note: "可现场建档", tag: "社区门诊", scope: "①③④", lat: 23.1275, lng: 113.2656, star: false),
        Clinic(name: "广东省妇幼保健院（番禺院区）预防接种门诊", city: "广州", district: "番禺区", address: "番禺区南村镇兴南大道 521 号", phone: "020-39151500", hours: "周一至周日 8:00-12:00 14:00-17:00", vaccines: "卡介苗、儿童及成人疫苗齐全", note: "产科接种点，新生儿首针可现场接种", tag: "省级三甲", scope: "①②③④", lat: 23.0028, lng: 113.3625, star: true),
        Clinic(name: "深圳市福田区莲花二村社区健康服务中心预防接种门诊", city: "深圳", district: "福田区", address: "福田区红荔西路莲花二村 16 栋 1 楼", phone: "0755-83948257", hours: "周二、三、四、六 8:00-11:30 14:00-17:00", vaccines: "免疫规划疫苗 + 水痘、手足口、流感、肺炎", note: "深圳接种范围 ① = 儿童免疫规划（除卡介苗）", tag: "社康中心", scope: "①③④", lat: 22.5465, lng: 114.0640, star: false),
        Clinic(name: "深圳市儿童医院预防接种特需门诊", city: "深圳", district: "福田区", address: "福田区益田路 7019 号", phone: "0755-83008340", hours: "周一至周五 8:00-12:00", vaccines: "卡介苗、乙肝首针及特需疫苗", note: "仅限特殊健康状态儿童", tag: "专科医院", scope: "②④", lat: 22.5522, lng: 114.0575, star: true),
        Clinic(name: "深圳市罗湖区翠岭社区健康服务中心预防接种门诊", city: "深圳", district: "罗湖区", address: "罗湖区翠竹街道太宁路 67 号科技大厦门诊楼二楼", phone: "0755-25793798", hours: "周一至周六 8:30-11:30 14:00-17:00", vaccines: "免疫规划疫苗 + 自费疫苗", note: "地铁布心站 D 口步行 90 米", tag: "社康中心", scope: "①③④", lat: 22.5673, lng: 114.1396, star: false),
        Clinic(name: "深圳市龙岗区第二人民医院大芬社区健康服务中心", city: "深圳", district: "龙岗区", address: "龙岗区布吉街道大芬油画街 28 号", phone: "0755-28706825", hours: "周二至周六 8:00-11:30", vaccines: "免疫规划疫苗", note: "可通过「社康通」预约", tag: "社康中心", scope: "①③④", lat: 22.6108, lng: 114.1373, star: false),
        Clinic(name: "深圳宝田医院预防接种门诊", city: "深圳", district: "光明区", address: "光明区马田街道松白路 4253 号", phone: "0755-27129993", hours: "周二至周六 8:00-11:30 14:00-17:00", vaccines: "免疫规划疫苗 + 自费二类", note: "光明区规模较大接种门诊", tag: "医院门诊", scope: "①③④", lat: 22.7476, lng: 113.9174, star: false),
        Clinic(name: "佛山市第一人民医院预防接种门诊", city: "佛山", district: "禅城区", address: "禅城区岭南大道北 81 号", phone: "0757-83163155", hours: "周一至周五 8:00-12:00", vaccines: "免疫规划疫苗 + HPV、流感、肺炎", note: "需提前预约", tag: "三甲医院", scope: "①③④", lat: 23.0175, lng: 113.1315, star: true),
        Clinic(name: "佛山市禅城区祖庙街道社区卫生服务中心", city: "佛山", district: "禅城区", address: "禅城区亲仁路 6 号", phone: "0757-82253613", hours: "周二至周六 8:00-11:30", vaccines: "免疫规划疫苗 + 水痘、手足口、流感", note: "老城区，周边居民多", tag: "社区门诊", scope: "①③④", lat: 23.0253, lng: 113.1097, star: false),
        Clinic(name: "东莞市厚街镇社区卫生服务中心预防接种门诊", city: "东莞", district: "厚街镇", address: "厚街镇厚街大道西 87 号", phone: "0769-85961236", hours: "周二至周六 8:00-11:30 14:30-17:00", vaccines: "免疫规划疫苗 + 水痘、手足口、流感", note: "统一使用「粤苗」预约", tag: "社区门诊", scope: "①③④", lat: 22.9258, lng: 113.6786, star: false),
        Clinic(name: "东莞市人民医院预防接种门诊", city: "东莞", district: "万江街道", address: "万江街道万道路 78 号", phone: "0769-28637333", hours: "周一至周五 8:00-12:00 14:30-17:30", vaccines: "免疫规划疫苗 + 自费疫苗齐全", note: "市属医院，号源较充足", tag: "三甲医院", scope: "①③④", lat: 23.0272, lng: 113.7178, star: true),
        Clinic(name: "珠海市妇幼保健院（南琴院区）预防接种门诊", city: "珠海", district: "香洲区", address: "香洲区南琴路 3366 号", phone: "0756-2313115", hours: "周一至周日 8:00-12:00 14:00-17:00", vaccines: "卡介苗、儿童疫苗、成人疫苗", note: "「健康珠海」公众号预约", tag: "三甲医院", scope: "①②③④", lat: 22.2108, lng: 113.5589, star: true),
        Clinic(name: "珠海市香洲区翠香社区卫生服务中心", city: "珠海", district: "香洲区", address: "香洲区翠香路 96 号", phone: "0756-2210425", hours: "周二至周六 8:00-11:30", vaccines: "免疫规划疫苗 + 水痘、流感", note: "主城区老牌社区门诊", tag: "社区门诊", scope: "①③④", lat: 22.2780, lng: 113.5773, star: false),
        Clinic(name: "中山市博爱医院预防接种门诊", city: "中山", district: "东区", address: "东区城桂路 6 号", phone: "0760-88306123", hours: "周一至周五 8:00-12:00 14:30-17:30", vaccines: "免疫规划疫苗 + 自费疫苗", note: "「健康中山」APP 预约", tag: "三甲医院", scope: "①③④", lat: 22.5178, lng: 113.3967, star: true),
        Clinic(name: "惠州市第一人民医院预防接种门诊", city: "惠州", district: "惠城区", address: "惠城区江北三新南路 20 号", phone: "0752-2883800", hours: "周一至周五 8:00-12:00", vaccines: "免疫规划疫苗 + HPV、流感", note: "关注「惠州疾控」获取门诊公告", tag: "三甲医院", scope: "①③④", lat: 23.1139, lng: 114.4167, star: true),
        Clinic(name: "汕头市中心医院预防接种门诊", city: "汕头", district: "金平区", address: "金平区外马路 114 号", phone: "0754-88908809", hours: "周一至周五 8:00-12:00", vaccines: "免疫规划疫苗 + 自费疫苗", note: "关注「健康汕头」公众号", tag: "三甲医院", scope: "①③④", lat: 23.3553, lng: 116.6800, star: true),
        Clinic(name: "湛江市妇幼保健院预防接种门诊", city: "湛江", district: "赤坎区", address: "赤坎区中华路 1 号", phone: "0759-3119067", hours: "周一至周五 8:00-12:00", vaccines: "儿童免疫规划疫苗、卡介苗", note: "「健康湛江」公众号查询", tag: "三甲医院", scope: "①③④", lat: 21.2715, lng: 110.3606, star: true)
    ]

    // MARK: 阶段重点

    static let milestones: [(maxMonth: Int, items: [String])] = [
        (3, ["俯卧抬头练习，每天 3–5 次", "按需喂养，观察每天 6 片以上湿尿布", "出生 42 天做首次儿保体检"]),
        (6, ["练习翻身、手抓握", "开始补充维生素 D（400 IU/天）", "准备添加辅食，从铁强化米粉开始"]),
        (12, ["逐步过渡到家庭食物，1 岁前不加盐糖", "练习独坐、爬行、扶站", "6–8 月龄查血常规，关注贫血"]),
        (24, ["每天户外活动 ≥ 2 小时", "语言爆发期，多对话少屏幕", "1 岁半做一次口腔检查"]),
        (36, ["练习自己用勺、如厕训练", "每年 1 次视力筛查", "接种 3 岁流脑疫苗"]),
        (72, ["保证每天 10–13 小时睡眠", "限制含糖饮料，每天奶量 300–500ml", "每半年测一次身高体重"]),
        (132, ["关注体态与视力，每天户外 2 小时", "每年身高增长应 ≥ 5cm", "记录换牙与青春期发育迹象"]),
        (999, ["每年测一次身高体重与血压", "关注脊柱侧弯与近视进展", "保证蛋白质与钙摄入，睡眠 ≥ 8 小时"])
    ]
}
