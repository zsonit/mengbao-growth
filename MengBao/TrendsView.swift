import SwiftUI
import Charts

// MARK: - 成长趋势指标

enum TrendMetric: String, CaseIterable, Identifiable {
    case sleep, milk, diaper, pumping, solid, temp, weight, height, headCirc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: return "睡眠"
        case .milk: return "奶量"
        case .diaper: return "尿布"
        case .pumping: return "吸奶"
        case .solid: return "辅食次数"
        case .temp: return "体温"
        case .weight: return "体重"
        case .height: return "身高"
        case .headCirc: return "头围"
        }
    }

    var icon: String {
        switch self {
        case .sleep: return "😴"
        case .milk: return "🍼"
        case .diaper: return "🧷"
        case .pumping: return "🧴"
        case .solid: return "🍚"
        case .temp: return "🌡️"
        case .weight: return "⚖️"
        case .height: return "📏"
        case .headCirc: return "🧢"
        }
    }

    var unit: String {
        switch self {
        case .sleep: return "分钟"
        case .milk, .pumping: return "ml"
        case .diaper, .solid: return "次"
        case .temp: return "℃"
        case .weight: return "kg"
        case .height, .headCirc: return "cm"
        }
    }

    var color: Color {
        switch self {
        case .sleep: return Color.adaptive(light: 0x5B7CFA, dark: 0x8FA9FF)
        case .milk: return Color.adaptive(light: 0xE2A33C, dark: 0xE9B95C)
        case .diaper: return Color.adaptive(light: 0x1F9D6B, dark: 0x3EC48D)
        case .pumping: return Color.adaptive(light: 0xB06BD6, dark: 0xCE9AE8)
        case .solid: return Color.adaptive(light: 0xD97706, dark: 0xE9A23B)
        case .temp: return Color.adaptive(light: 0xE0513A, dark: 0xF2715C)
        case .weight: return Color.adaptive(light: 0x7C5CFF, dark: 0x9B82FF)
        case .height: return Color.adaptive(light: 0x2C8BC9, dark: 0x62B2E6)
        case .headCirc: return Color.adaptive(light: 0x4CA6A0, dark: 0x77C7C1)
        }
    }

    /// 曲线来自哪类喂养记录（体型类返回 nil）
    var feedKind: FeedLog.Kind? {
        switch self {
        case .sleep: return .sleep
        case .milk: return .bottle
        case .diaper: return .diaper
        case .pumping: return .pumping
        case .solid: return .solid
        case .temp: return .temp
        default: return nil
        }
    }

    var isDaily: Bool {
        switch self {
        case .sleep, .milk, .diaper, .pumping, .solid: return true
        default: return false
        }
    }
}

// MARK: - 曲线数据点

struct TrendPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    /// true = 这一天的合计（时刻是当天 0 点，不代表具体几点几分）
    let isDailySum: Bool
    let value: Double

    static func == (lhs: TrendPoint, rhs: TrendPoint) -> Bool { lhs.id == rhs.id }
}

enum TrendSeries {
    /// 短周期（≤7 天）里，能按「一次一条记录」描点的指标就按次画，时间才能精确到几点几分
    static func perRecord(_ metric: TrendMetric, days: Int?) -> Bool {
        guard let days else { return false }
        guard days <= 7 else { return false }
        switch metric {
        case .sleep, .milk, .pumping, .temp, .weight, .height, .headCirc: return true
        default: return false   // 尿布/辅食次数按次会是一条水平线，保持按天汇总
        }
    }

    /// 取某个指标的曲线点；days = nil 表示全部历史，否则是最近 N 天（含今天）
    static func points(for metric: TrendMetric, child: Child, days: Int?) -> [TrendPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let cutoff = days.map { today.addingTimeInterval(-Double($0 - 1) * 86400) }

        func inRange(_ day: Date) -> Bool { cutoff.map { day >= $0 } ?? true }
        let byRecord = perRecord(metric, days: days)

        switch metric {
        case .sleep, .milk, .diaper, .pumping, .solid:
            guard let kind = metric.feedKind else { return [] }
            if byRecord {
                return child.feeds.compactMap { f -> TrendPoint? in
                    guard f.kind == kind, inRange(cal.startOfDay(for: f.date)) else { return nil }
                    let v: Double
                    switch metric {
                    case .sleep: v = Double(f.minutes ?? 0)
                    default: v = f.ml ?? 0
                    }
                    guard v > 0 else { return nil }
                    return TrendPoint(id: "\(metric.rawValue)-\(f.id.uuidString)", date: f.date, isDailySum: false, value: v)
                }
                .sorted { $0.date < $1.date }
            }
            var byDay: [Date: Double] = [:]
            for f in child.feeds where f.kind == kind {
                let day = cal.startOfDay(for: f.date)
                guard inRange(day) else { continue }
                let v: Double
                switch metric {
                case .sleep: v = Double(f.minutes ?? 0)
                case .milk, .pumping: v = f.ml ?? 0
                case .diaper, .solid: v = 1
                default: v = 0
                }
                byDay[day, default: 0] += v
            }
            return byDay
                .filter { $0.value > 0 }
                .map { TrendPoint(id: "\(metric.rawValue)-\($0.key.timeIntervalSince1970)", date: $0.key, isDailySum: true, value: $0.value) }
                .sorted { $0.date < $1.date }

        case .temp:
            return child.feeds.compactMap { f -> TrendPoint? in
                guard f.kind == .temp, let v = f.value, inRange(cal.startOfDay(for: f.date)) else { return nil }
                return TrendPoint(id: "temp-\(f.id.uuidString)", date: f.date, isDailySum: false, value: v)
            }
            .sorted { $0.date < $1.date }

        case .weight, .height, .headCirc:
            return child.records.compactMap { r -> TrendPoint? in
                let v: Double?
                switch metric {
                case .weight: v = r.weight
                case .height: v = r.height
                default: v = r.headCirc
                }
                guard let v, inRange(cal.startOfDay(for: r.date)) else { return nil }
                return TrendPoint(id: "\(metric.rawValue)-\(r.id.uuidString)", date: r.date, isDailySum: false, value: v)
            }
            .sorted { $0.date < $1.date }
        }
    }

    // MARK: - 时间文案（精确到年/月/日/时/分）

    static func hasClock(_ date: Date) -> Bool {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) != 0 || (c.minute ?? 0) != 0
    }

    /// "2026年11月1日" / "2026年11月1日 08:30"
    static func stamp(_ date: Date, withTime: Bool) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = withTime ? "yyyy年M月d日 HH:mm" : "yyyy年M月d日"
        return f.string(from: date)
    }

    /// 曲线点的完整标签
    static func stamp(_ p: TrendPoint) -> String {
        if p.isDailySum { return stamp(p.date, withTime: false) + " 全天" }
        return stamp(p.date, withTime: hasClock(p.date))
    }

    /// 横轴刻度标签：跨度越长越粗
    static func axisLabel(_ date: Date, spanDays: Double) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        if spanDays <= 2 { f.dateFormat = "HH:mm" }
        else if spanDays <= 10 { f.dateFormat = "M/d HH:mm" }
        else if spanDays <= 400 { f.dateFormat = "M月d日" }
        else { f.dateFormat = "yyyy年M月" }
        return f.string(from: date)
    }

    /// 某个指标的当日合计文案（曲线点说明用）
    static func describe(_ metric: TrendMetric, value: Double) -> String {
        switch metric {
        case .sleep:
            let h = Int(value) / 60, m = Int(value) % 60
            return h > 0 ? "\(h) 小时 \(m) 分钟" : "\(m) 分钟"
        case .milk, .pumping: return "\(Int(value)) ml"
        case .diaper, .solid: return "\(Int(value)) 次"
        case .temp: return String(format: "%.1f ℃", value)
        case .weight: return String(format: "%.2f kg", value)
        case .height, .headCirc: return String(format: "%.1f cm", value)
        }
    }
}

// MARK: - 成长趋势页

struct TrendsView: View {
    @EnvironmentObject private var store: Store
    @State private var metric: TrendMetric = .sleep
    @State private var rangeDays: Int? = 30
    @State private var selected: TrendPoint?
    @State private var sheetTarget: SheetTarget?

    private var ranges: [(String, Int?)] {
        [("今天", 1), ("3 天", 3), ("5 天", 5), ("7 天", 7),
         ("15 天", 15), ("30 天", 30), ("90 天", 90), ("全部", nil)]
    }

    var body: some View {
        ScrollView {
            if let child = store.current {
                content(child)
            } else {
                EmptyHint(text: "先添加宝宝档案")
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("成长趋势")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheetTarget) { target in
            NavigationStack {
                DayHistoryView(initialDate: target.date, initialMetric: target.metric)
            }
        }
    }

    private struct SheetTarget: Identifiable {
        let date: Date
        let metric: TrendMetric?
        var id: String { "\(date.timeIntervalSince1970)-\(metric?.rawValue ?? "all")" }
    }

    private func content(_ child: Child) -> some View {
        let points = TrendSeries.points(for: metric, child: child, days: rangeDays)
        let latest = points.last

        return VStack(spacing: 0) {
            // 指标选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TrendMetric.allCases) { m in
                        Button {
                            metric = m
                            selected = nil
                        } label: {
                            HStack(spacing: 4) {
                                Text(m.icon).font(.system(size: 12))
                                Text(m.title).font(.system(size: 12.5, weight: metric == m ? .semibold : .regular))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(metric == m ? Palette.purple : Palette.purpleTint)
                            .foregroundColor(metric == m ? .white : Palette.ink2)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(metric == m ? Palette.purple : Palette.hairline))
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 6)

            // 时间范围
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ranges, id: \.1) { label, days in
                        Button {
                            rangeDays = days
                            selected = nil
                        } label: {
                            Text(label)
                                .font(.system(size: 12, weight: rangeDays == days ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(rangeDays == days ? Palette.purpleSoft : Color.clear)
                                .foregroundColor(rangeDays == days ? Palette.purple : Palette.subtle)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(rangeDays == days ? Palette.purple.opacity(0.25) : Color.clear))
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.top, 10)

            HStack {
                Text(TrendSeries.perRecord(metric, days: rangeDays)
                     ? "按次描点 · 每个点是一个时刻"
                     : "按天汇总 · 每个点是一天的合计")
                    .font(.system(size: 11)).foregroundColor(Palette.subtle)
                Spacer()
                Text("单位：\(metric.unit)").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)

            // 曲线卡
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(metric.icon) \(metric.title)曲线")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    Spacer()
                    if let latest {
                        Text("最新 \(TrendSeries.describe(metric, value: latest.value))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(metric.color)
                    }
                }
                if let latest {
                    Text(TrendSeries.stamp(latest))
                        .font(.system(size: 11.5))
                        .foregroundColor(Palette.subtle)
                }

                if points.isEmpty {
                    VStack(spacing: 6) {
                        Text("这个区间这个指标还没有记录")
                            .font(.system(size: 13)).foregroundColor(Palette.subtle)
                        Text("换一个时间范围，或先在首页补一条记录")
                            .font(.system(size: 11.5)).foregroundColor(Palette.subtle.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 34)
                } else {
                    let span = points.count > 1
                        ? points[points.count - 1].date.timeIntervalSince(points[0].date) / 86400
                        : 0
                    Chart {
                        if let sel = selected {
                            RuleMark(x: .value("选中", sel.date))
                                .foregroundStyle(metric.color.opacity(0.28))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }
                        ForEach(points) { p in
                            if points.count > 1 {
                                LineMark(x: .value("时间", p.date), y: .value(metric.title, p.value))
                                    .foregroundStyle(metric.color)
                                    .interpolationMethod(.catmullRom)
                                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                            }
                            PointMark(x: .value("时间", p.date), y: .value(metric.title, p.value))
                                .foregroundStyle(metric.color)
                                .symbolSize(p.id == selected?.id ? 80 : 30)
                        }
                    }
                    .chartYScale(domain: yDomain(points))
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: span > 10 ? 3 : 4)) { v in
                            AxisGridLine().foregroundStyle(Palette.hairlineSoft)
                            AxisValueLabel {
                                if let d = v.as(Date.self) {
                                    Text(TrendSeries.axisLabel(d, spanDays: span))
                                        .font(.system(size: 9.5))
                                        .foregroundColor(Palette.subtle)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                            AxisGridLine().foregroundStyle(Palette.hairlineSoft)
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text(axisText(d))
                                        .font(.system(size: 9.5))
                                        .foregroundColor(Palette.subtle)
                                }
                            }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { _ in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onEnded { g in
                                            guard let date: Date = proxy.value(atX: g.location.x, as: Date.self) else { return }
                                            selected = points.min {
                                                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                            }
                                        }
                                )
                        }
                    }
                    .frame(height: 226)
                }

                // 点选信息（精确到年/月/日/时/分）+ 跳当日明细
                if let sel = selected {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(metric.icon) \(TrendSeries.stamp(sel))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Palette.ink)
                            Spacer()
                            Text(TrendSeries.describe(metric, value: sel.value))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(metric.color)
                        }
                        Button {
                            sheetTarget = SheetTarget(date: sel.date, metric: metric)
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath").font(.system(size: 12))
                                Text(sel.isDailySum ? "查看这天的全部明细" : "查看这天的明细")
                                    .font(.system(size: 12.5, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 10))
                            }
                            .foregroundColor(Palette.purple)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(Palette.purpleTint)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                    .transition(.opacity)
                }

                HStack(spacing: 12) {
                    Text("点一下曲线可以看这一点的年月日时分").font(.system(size: 11)).foregroundColor(Palette.subtle)
                    Spacer()
                    Button {
                        sheetTarget = SheetTarget(date: Date(), metric: nil)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar").font(.system(size: 11))
                            Text("按日期看历史").font(.system(size: 11.5, weight: .medium))
                        }
                        .foregroundColor(Palette.purple)
                    }
                    .buttonStyle(SoftPressStyle())
                }
                .padding(.top, 2)
            }
            .cardStyle()
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // 当日快览
            dayPeek(child)

            Spacer(minLength: 28)
        }
    }

    /// Y 轴留点上下余量；只有一个点时也能画出图
    private func yDomain(_ pts: [TrendPoint]) -> ClosedRange<Double> {
        let vals = pts.map(\.value)
        guard let mn = vals.min(), let mx = vals.max() else { return 0...1 }
        if mn == mx {
            let pad = max(abs(mn) * 0.12, 1)
            return (mn - pad)...(mx + pad)
        }
        let pad = (mx - mn) * 0.15
        return (mn - pad)...(mx + pad)
    }

    private func axisText(_ v: Double) -> String {
        switch metric {
        case .temp, .weight, .height, .headCirc:
            return String(format: "%.1f", v)
        default:
            return v >= 100 ? "\(Int(v.rounded()))" : String(format: "%.1f", v)
        }
    }

    /// 今天数据一瞥
    private func dayPeek(_ child: Child) -> some View {
        let cal = Calendar.current
        let todayFeeds = child.feeds.filter { cal.isDate($0.date, inSameDayAs: Date()) }
        let lines: [String] = [
            "😴 睡眠 \(todayFeeds.filter { $0.kind == .sleep }.reduce(0) { $0 + ($1.minutes ?? 0) }) 分钟",
            "🍼 奶量 \(Int(todayFeeds.filter { $0.kind == .bottle }.reduce(0.0) { $0 + ($1.ml ?? 0) })) ml",
            "🧷 尿布 \(todayFeeds.filter { $0.kind == .diaper }.count) 次",
            "🧴 吸奶 \(Int(todayFeeds.filter { $0.kind == .pumping }.reduce(0.0) { $0 + ($1.ml ?? 0) })) ml",
            "🍚 辅食 \(todayFeeds.filter { $0.kind == .solid }.count) 次",
        ]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今天 · \(TrendSeries.stamp(Date(), withTime: false))").font(.system(size: 13, weight: .semibold)).foregroundColor(Palette.ink)
                Spacer()
                Button {
                    sheetTarget = SheetTarget(date: Date(), metric: nil)
                } label: {
                    HStack(spacing: 3) {
                        Text("全天明细").font(.system(size: 12))
                        Image(systemName: "chevron.right").font(.system(size: 9))
                    }
                    .foregroundColor(Palette.purple)
                }
                .buttonStyle(SoftPressStyle())
            }
            Text(lines.joined(separator: "　"))
                .font(.system(size: 12.5))
                .foregroundColor(Palette.ink2)
        }
        .cardStyle()
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - 当日明细（精确到几点几分）

struct DayHistoryView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var initialDate: Date
    @State var initialMetric: TrendMetric?
    @State private var day: Date
    @State private var filter: TrendMetric?

    init(initialDate: Date, initialMetric: TrendMetric?) {
        _initialDate = State(initialValue: initialDate)
        _initialMetric = State(initialValue: initialMetric)
        _day = State(initialValue: initialDate)
        _filter = State(initialValue: initialMetric)
    }

    var body: some View {
        ScrollView {
            if let child = store.current {
                content(child)
            } else {
                EmptyHint(text: "先添加宝宝档案")
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("当日明细")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
    }

    private struct Entry: Identifiable {
        let id: String
        let at: Date?          // nil = 无具体时刻（生长测量）
        let icon: String
        let title: String
        let detail: String
        let note: String
        let metric: TrendMetric?
    }

    private func content(_ child: Child) -> some View {
        let cal = Calendar.current
        let entries = buildEntries(child: child, day: day)

        return VStack(spacing: 0) {
            // 日期导航
            HStack(spacing: 10) {
                Button {
                    day = cal.date(byAdding: .day, value: -1, to: day) ?? day
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Palette.purple)
                        .padding(8)
                        .background(Palette.purpleTint)
                        .clipShape(Circle())
                }
                .buttonStyle(SoftPressStyle())

                DatePicker("", selection: $day, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))

                Button {
                    day = cal.date(byAdding: .day, value: 1, to: day) ?? day
                } label: {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(cal.compare(day, to: Date(), toGranularity: .day) == .orderedSame ? Palette.hairline : Palette.purple)
                        .padding(8)
                        .background(cal.compare(day, to: Date(), toGranularity: .day) == .orderedSame ? Palette.hairlineSoft : Palette.purpleTint)
                        .clipShape(Circle())
                }
                .buttonStyle(SoftPressStyle())
                .disabled(cal.compare(day, to: Date(), toGranularity: .day) == .orderedSame)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // 指标筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("全部", metric: nil)
                    ForEach(TrendMetric.allCases) { m in
                        chip("\(m.icon) \(m.title)", metric: m)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)

            // 明细列表
            let visible = filter.map { f in entries.filter { $0.metric == f } } ?? entries
            if visible.isEmpty {
                VStack(spacing: 6) {
                    Text("这天没有相关记录").font(.system(size: 13.5)).foregroundColor(Palette.subtle)
                    Text("在首页点「＋」或语音说一句就能补记").font(.system(size: 12)).foregroundColor(Palette.subtle.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 46)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { idx, e in
                        if idx > 0 { Divider().overlay(Palette.hairlineSoft) }
                        HStack(alignment: .top, spacing: 11) {
                            Text(e.icon).font(.system(size: 17))
                            VStack(alignment: .leading, spacing: 2.5) {
                                Text(e.title).font(.system(size: 14, weight: .medium)).foregroundColor(Palette.ink)
                                Text(e.detail).font(.system(size: 12.5)).foregroundColor(Palette.ink2)
                                if !e.note.isEmpty {
                                    Text("📝 \(e.note)").font(.system(size: 12)).foregroundColor(Palette.subtle)
                                }
                            }
                            Spacer()
                            Text(e.at.map { $0.formatted(date: .omitted, time: .shortened) } ?? "全天")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(e.at == nil ? Palette.subtle : Palette.purple)
                        }
                        .padding(.vertical, 10)
                    }
                }
                .cardStyle()
                .padding(.horizontal, 16)
            }

            Text("共 \(visible.count) 条 · 睡眠/奶量/尿布/吸奶/辅食/体温来自喂养记录，体重/身高/头围来自生长测量")
                .font(.system(size: 11))
                .foregroundColor(Palette.subtle)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Spacer(minLength: 28)
        }
    }

    private func chip(_ text: String, metric: TrendMetric?) -> some View {
        Button {
            filter = metric
        } label: {
            Text(text)
                .font(.system(size: 12.5, weight: filter == metric ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(filter == metric ? Palette.purple : Palette.purpleTint)
                .foregroundColor(filter == metric ? .white : Palette.ink2)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(filter == metric ? Palette.purple : Palette.hairline))
        }
        .buttonStyle(SoftPressStyle())
    }

    private func buildEntries(child: Child, day: Date) -> [Entry] {
        let cal = Calendar.current
        var list: [Entry] = []

        for f in child.feeds where cal.isDate(f.date, inSameDayAs: day) {
            let metric: TrendMetric?
            let title: String
            let detail: String
            switch f.kind {
            case .sleep:
                metric = .sleep; title = "睡眠"
                detail = "\(f.minutes ?? 0) 分钟"
            case .bottle:
                metric = .milk; title = "瓶喂"
                detail = "\(Int(f.ml ?? 0)) ml"
            case .breast:
                metric = nil; title = "亲喂"
                detail = "\(f.side ?? "左")侧 · \(f.minutes ?? 0) 分钟"
            case .pumping:
                metric = .pumping; title = "吸奶"
                detail = "\(Int(f.ml ?? 0)) ml"
            case .diaper:
                metric = .diaper; title = "尿布"
                detail = f.diaperKind ?? "小便"
            case .solid:
                metric = .solid; title = "辅食"
                detail = f.note.isEmpty ? "已添加" : f.note
            case .temp:
                metric = .temp; title = "体温"
                detail = String(format: "%.1f ℃", f.value ?? 0)
            case .supplement:
                metric = nil; title = "补剂"
                detail = f.note.isEmpty ? "已服用" : f.note
            case .custom:
                metric = nil; title = "记录"
                detail = f.note.isEmpty ? "—" : f.note
            }
            list.append(Entry(
                id: "f-\(f.id.uuidString)",
                at: f.date, icon: f.kind.icon,
                title: title, detail: detail, note: f.note, metric: metric,
            ))
        }

        for r in child.records where cal.isDate(r.date, inSameDayAs: day) {
            if let h = r.height {
                list.append(Entry(id: "r-h-\(r.id.uuidString)", at: nil, icon: "📏", title: "身高测量", detail: String(format: "%.1f cm", h), note: r.note, metric: .height))
            }
            if let w = r.weight {
                list.append(Entry(id: "r-w-\(r.id.uuidString)", at: nil, icon: "⚖️", title: "体重测量", detail: String(format: "%.2f kg", w), note: r.note, metric: .weight))
            }
            if let hc = r.headCirc {
                list.append(Entry(id: "r-hc-\(r.id.uuidString)", at: nil, icon: "🧢", title: "头围测量", detail: String(format: "%.1f cm", hc), note: r.note, metric: .headCirc))
            }
            if let fl = r.footLength, r.height == nil, r.weight == nil, r.headCirc == nil {
                list.append(Entry(id: "r-fl-\(r.id.uuidString)", at: nil, icon: "📝", title: "生长测量", detail: "脚长 \(String(format: "%.1f", fl)) cm", note: r.note, metric: nil))
            }
        }

        return list.sorted { a, b in
            switch (a.at, b.at) {
            case let (x?, y?): return x < y
            case (nil, _?): return false
            case (_?, nil): return true
            default: return a.id < b.id
            }
        }
    }
}
