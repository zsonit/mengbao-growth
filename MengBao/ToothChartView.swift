import SwiftUI

// MARK: - 乳牙标准（与安卓 Kotlin 版 ToothStandard 保持一致）

/// 一颗乳牙的定义：FDI 编码 + 名称 + 正常换牙期（月龄区间）
struct ToothDef: Identifiable, Hashable {
    let code: Int          // FDI 编码：51-55 上颌左，61-65 上颌右，71-75 下颌左，81-85 下颌右
    let name: String
    let earlyMonths: Int   // 换牙期开始（月龄）
    let lateMonths: Int    // 换牙期结束（月龄）
    var id: Int { code }
    var isUpper: Bool { code < 70 }
    var side: Int { (code % 10) - 1 }   // 0=中切 … 4=第二磨牙

    var windowLabel: String {
        let f = { (m: Int) in m % 12 == 0 ? "\(m / 12)岁" : String(format: "%d岁半", m / 12) }
        return "\(f(earlyMonths)) ~ \(f(lateMonths))"
    }

    /// 去掉"上乳/下乳"前缀的短名，用于牙位小方块的第二行
    var shortName: String {
        name.replacingOccurrences(of: "上乳", with: "")
            .replacingOccurrences(of: "下乳", with: "")
    }

    /// 上颌牙弓从左到右的展示顺序
    static let upperOrder = [55, 54, 53, 52, 51, 61, 62, 63, 64, 65]
    /// 下颌牙弓从左到右的展示顺序
    static let lowerOrder = [85, 84, 83, 82, 81, 71, 72, 73, 74, 75]

    static let all: [Int: ToothDef] = {
        var dict: [Int: ToothDef] = [:]
        let table: [(Int, String, Int, Int)] = [
            (51, "上乳中切牙", 72, 96), (52, "上乳侧切牙", 84, 102), (53, "上乳尖牙", 114, 144),
            (54, "上乳第一磨牙", 114, 138), (55, "上乳第二磨牙", 120, 150),
            (61, "上乳中切牙", 72, 96), (62, "上乳侧切牙", 84, 102), (63, "上乳尖牙", 114, 144),
            (64, "上乳第一磨牙", 114, 138), (65, "上乳第二磨牙", 120, 150),
            (71, "下乳中切牙", 66, 84), (72, "下乳侧切牙", 78, 96), (73, "下乳尖牙", 108, 126),
            (74, "下乳第一磨牙", 108, 132), (75, "下乳第二磨牙", 114, 138),
            (81, "下乳中切牙", 66, 84), (82, "下乳侧切牙", 78, 96), (83, "下乳尖牙", 108, 126),
            (84, "下乳第一磨牙", 108, 132), (85, "下乳第二磨牙", 114, 138),
        ]
        for (code, name, early, late) in table {
            dict[code] = ToothDef(code: code, name: name, earlyMonths: early, lateMonths: late)
        }
        return dict
    }()
}

/// 牙齿状态
enum ToothStatus: Hashable {
    case fallen, overdue, warn, normal

    var label: String {
        switch self {
        case .fallen: return "已脱落/换牙"
        case .overdue: return "超期未换"
        case .warn: return "临近/预警"
        case .normal: return "未到换牙期"
        }
    }

    var color: Color {
        switch self {
        case .fallen: return Palette.ok
        case .overdue: return Palette.purpleDeep
        case .warn: return Palette.warn
        case .normal: return Palette.subtle
        }
    }

    var softColor: Color {
        switch self {
        case .fallen: return Palette.okBg
        case .overdue: return Palette.purpleSoft
        case .warn: return Palette.warnBg
        case .normal: return Palette.hairlineSoft
        }
    }
}

/// 一颗牙当前的综合状态（含脱落日期 + 龋齿记录）
struct ToothState {
    let def: ToothDef
    let status: ToothStatus
    let fallenDate: Date?
    var decay: ToothDecay? = nil
}

/// 龋齿程度的配色
enum DecayTone {
    static func color(_ severity: Int) -> Color {
        switch severity {
        case 3: return Palette.bad
        case 2: return Palette.warn
        default: return Color(hex: 0xC08A2E)
        }
    }

    static func bg(_ severity: Int) -> Color {
        switch severity {
        case 3: return Palette.badBg
        case 2: return Palette.warnBg
        default: return Palette.warnBg.opacity(0.65)
        }
    }
}

/// 单颗牙状态的统一计算（主页面与详情页共用，保证两边一致）
enum ToothEngine {
    static func state(code: Int, child: Child, ageMonths: Int? = nil) -> ToothState {
        guard let def = ToothDef.all[code] else {
            return ToothState(def: ToothDef(code: code, name: "牙位 \(code)", earlyMonths: 0, lateMonths: 0),
                              status: .normal, fallenDate: nil)
        }
        let months = ageMonths ?? (Calendar.current.dateComponents([.month], from: child.birthDate, to: Date()).month ?? 0)
        let fallen = (child.teethFallen ?? [:])[code]
        let status: ToothStatus
        if fallen != nil {
            status = .fallen
        } else if months > def.lateMonths {
            status = .overdue
        } else if months >= def.earlyMonths - 6 {
            status = .warn
        } else {
            status = .normal
        }
        return ToothState(def: def, status: status, fallenDate: fallen, decay: (child.teethDecay ?? [:])[code])
    }
}

// MARK: - 主视图

struct ToothChartView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let child: Child

    @State private var tab = 0
    @State private var selected: ToothSelection? = nil
    @State private var showDecayPicker = false

    private var ageMonths: Int {
        Calendar.current.dateComponents([.month], from: child.birthDate, to: Date()).month ?? 0
    }

    private var fallenMap: [Int: Date] { child.teethFallen ?? [:] }
    private var decayMap: [Int: ToothDecay] { child.teethDecay ?? [:] }

    private func state(of code: Int) -> ToothState {
        ToothEngine.state(code: code, child: child, ageMonths: ageMonths)
    }

    private var allStates: [ToothState] { ToothDef.all.keys.sorted().map { state(of: $0) } }

    /// 龋齿清单：按牙位编码排序
    private var decayRows: [DecayRow] {
        ToothDef.all.keys.sorted().compactMap { code in
            guard let d = decayMap[code] else { return nil }
            return DecayRow(code: code, decay: d)
        }
    }

    private var needVisitCount: Int { decayRows.filter { $0.decay.needsVisit }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    pickerBar
                    if tab == 0 {
                        archSection
                    } else if tab == 1 {
                        scheduleSection
                    } else {
                        decaySection
                    }
                    hintCard
                }
                .padding(.vertical, 12)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("换牙档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .sheet(item: $selected) { sel in
                ToothDetailView(code: sel.code)
                    .environmentObject(store)
            }
        }
    }

    // 顶部统计卡
    private var summaryCard: some View {
        let states = allStates
        let counts: [ToothStatus: Int] = [
            .fallen: states.filter { $0.status == .fallen }.count,
            .warn: states.filter { $0.status == .warn }.count,
            .overdue: states.filter { $0.status == .overdue }.count,
            .normal: states.filter { $0.status == .normal }.count,
        ]
        let decayCount = decayRows.count
        return VStack(spacing: 12) {
            HStack {
                Text("儿童年龄：\(max(ageMonths / 12, 0))岁")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Text("总牙数 28 颗 · 乳牙 20 颗（6-12 岁换完）")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.subtle)
            }
            HStack(spacing: 0) {
                statCell(value: counts[.fallen]!, unit: "颗", label: "已脱落", color: Palette.ok)
                statCell(value: counts[.warn]!, unit: "颗", label: "临近/预警", color: Palette.warn)
                statCell(value: counts[.overdue]!, unit: "颗", label: "超期未换", color: Palette.purpleDeep)
                statCell(value: counts[.normal]!, unit: "颗", label: "未到换牙期", color: Palette.subtle)
            }
            // 20 格状态条
            HStack(spacing: 2) {
                ForEach(ToothDef.upperOrder + ToothDef.lowerOrder, id: \.self) { code in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(state(of: code).status.color)
                        .frame(height: 8)
                }
            }
            // 龋齿（烂牙）入口
            Button {
                withAnimation(Anim.tab) { tab = 2 }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: decayCount > 0 ? "exclamationmark.triangle.fill" : "bandage")
                        .font(.system(size: 11, weight: .bold))
                    Text(decayCount > 0 ? "已记录 \(decayCount) 颗龋齿（烂牙）" : "还没有记录龋齿（烂牙）")
                        .font(.system(size: 12, weight: .semibold))
                    if needVisitCount > 0 {
                        Text("· \(needVisitCount) 颗建议就诊")
                            .font(.system(size: 11.5))
                    }
                    Spacer(minLength: 4)
                    Text(decayCount > 0 ? "查看 →" : "去记录 →")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .foregroundColor(decayCount > 0 ? Palette.bad : Palette.purple)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(decayCount > 0 ? Palette.badBg : Palette.purpleTint)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(SoftPressStyle(scale: 0.98, dim: 0.9))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func statCell(value: Int, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)").font(.system(size: 20, weight: .bold)).foregroundColor(color)
                Text(unit).font(.system(size: 11)).foregroundColor(Palette.subtle)
            }
            Text(label).font(.system(size: 11)).foregroundColor(Palette.subtle)
        }
        .frame(maxWidth: .infinity)
    }

    private var pickerBar: some View {
        HStack(spacing: 0) {
            tabButton("牙弓图", index: 0)
            tabButton("换牙时间表", index: 1)
            tabButton("龋齿记录", index: 2)
        }
        .background(Palette.hairlineSoft)
        .clipShape(Capsule())
        .padding(.horizontal, 16)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(Anim.tab) { tab = index }
        } label: {
            Text(title)
                .font(.system(size: 13.5, weight: tab == index ? .semibold : .regular))
                .foregroundColor(tab == index ? Palette.ink : Palette.subtle)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if tab == index {
                            Capsule().fill(Palette.card)
                                .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                        }
                    }
                )
        }
        .buttonStyle(SoftPressStyle())
    }

    // 牙弓图
    private var archSection: some View {
        VStack(spacing: 0) {
            ArchChartView(states: ToothDef.upperOrder.map { state(of: $0) }, isUpper: true) { code in
                selected = ToothSelection(code: code)
            }
            ArchChartView(states: ToothDef.lowerOrder.map { state(of: $0) }, isUpper: false) { code in
                selected = ToothSelection(code: code)
            }
            legendRow
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var legendRow: some View {
        VStack(spacing: 5) {
            HStack(spacing: 12) {
                legendDot(ToothStatus.normal)
                legendDot(ToothStatus.warn)
                legendDot(ToothStatus.fallen)
                legendDot(ToothStatus.overdue)
            }
            HStack(spacing: 5) {
                Circle().fill(Palette.bad).frame(width: 8, height: 8)
                Text("龋齿（烂牙）· 牙冠右上角红点")
                    .font(.system(size: 10.5))
                    .foregroundColor(Palette.subtle)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private func legendDot(_ s: ToothStatus) -> some View {
        HStack(spacing: 4) {
            Circle().strokeBorder(s.color, lineWidth: 1.5).frame(width: 10, height: 10)
            Text(s.label).font(.system(size: 10.5)).foregroundColor(Palette.subtle)
        }
    }

    // 时间表
    private var scheduleSection: some View {
        VStack(spacing: 12) {
            scheduleGroup(title: "上颌（Maxillary）", codes: [51, 52, 53, 54, 55, 61, 62, 63, 64, 65])
            scheduleGroup(title: "下颌（Mandibular）", codes: [71, 72, 73, 74, 75, 81, 82, 83, 84, 85])
        }
        .padding(.horizontal, 16)
    }

    private func scheduleGroup(title: String, codes: [Int]) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Palette.subtle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                ForEach(codes, id: \.self) { code in
                    let st = state(of: code)
                    Button {
                        selected = ToothSelection(code: code)
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(code)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Palette.purple)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(st.def.name).font(.system(size: 14, weight: .medium)).foregroundColor(Palette.ink)
                                Text("换牙期 \(st.def.windowLabel)")
                                    .font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                if let d = st.fallenDate {
                                    Text("已脱落 · " + Self.fmt.string(from: d))
                                        .font(.system(size: 11.5)).foregroundColor(Palette.ok)
                                } else {
                                    Text(st.status.label)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundColor(st.status == .normal ? Palette.subtle : st.status.color)
                                }
                                if let d = st.decay {
                                    Text("🦷 龋齿 · \(d.severityLabel)")
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundColor(DecayTone.color(d.severity))
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SoftPressStyle(scale: 0.99, dim: 0.94))
                    if code != codes.last {
                        Divider().background(Palette.hairlineSoft)
                    }
                }
            }
            .cardStyle(padding: 4)
        }
    }

    // MARK: 龋齿记录

    private var decaySection: some View {
        let rows = decayRows
        return VStack(spacing: 12) {
            VStack(spacing: 0) {
                if rows.isEmpty {
                    VStack(spacing: 8) {
                        Text("🦷").font(.system(size: 30))
                        Text("还没有记录龋齿")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Palette.ink)
                        Text("发现哪颗牙有黑点、蛀洞或者孩子喊牙疼，就在这里记下来，复诊时一目了然。")
                            .font(.system(size: 12))
                            .foregroundColor(Palette.subtle)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 22)
                    .padding(.horizontal, 18)
                } else {
                    ForEach(rows) { row in
                        decayRow(row)
                        if row.code != rows.last?.code {
                            Divider().background(Palette.hairlineSoft)
                        }
                    }
                }
            }
            .cardStyle(padding: 6)
            .padding(.horizontal, 16)

            Button {
                showDecayPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text(rows.isEmpty ? "记录一颗龋齿（烂牙）" : "再记录一颗")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 16)
            .sheet(isPresented: $showDecayPicker) {
                ToothDecayEditorView(startCode: nil)
                    .environmentObject(store)
            }

            if !rows.isEmpty {
                Text("点任意一条可以补充备注或清除记录。中重度蛀牙建议尽快看儿童口腔科，乳牙龋坏会影响恒牙萌出和咀嚼。")
                    .font(.system(size: 11.5))
                    .foregroundColor(Palette.subtle)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            }
        }
    }

    private func decayRow(_ row: DecayRow) -> some View {
        let def = ToothDef.all[row.code]
        let tone = DecayTone.color(row.decay.severity)
        return Button {
            selected = ToothSelection(code: row.code)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DecayTone.bg(row.decay.severity))
                        .frame(width: 42, height: 46)
                    VStack(spacing: 1) {
                        Text("\(row.code)")
                            .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                            .foregroundColor(tone)
                        Text(def?.shortName ?? "")
                            .font(.system(size: 8))
                            .foregroundColor(tone.opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(def?.name ?? "牙位 \(row.code)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Palette.ink)
                        Text(row.decay.severityLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(tone)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(DecayTone.bg(row.decay.severity))
                            .clipShape(Capsule())
                    }
                    Text("记录于 " + Self.fmt.string(from: row.decay.date) + (row.decay.needsVisit ? " · 建议就诊" : ""))
                        .font(.system(size: 11.5))
                        .foregroundColor(row.decay.needsVisit ? Palette.warn : Palette.subtle)
                    if !row.decay.note.isEmpty {
                        Text(row.decay.note)
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.ink2)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Palette.subtle.opacity(0.55))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle(scale: 0.99, dim: 0.94))
    }

    static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var hintCard: some View {
        Text("点击牙弓图上的任意一颗牙，可以记录脱落日期、标记龋齿（烂牙）或恢复。换牙期为大多数孩子的普遍规律，个体差异 ±6 个月都属正常；「超期未换」建议请口腔科医生看看，确认恒牙萌出情况。")
            .font(.system(size: 11.5))
            .foregroundColor(Palette.subtle)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Palette.purpleTint)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
    }
}

/// 牙弓图点选的包装
struct ToothSelection: Identifiable {
    let code: Int
    var id: Int { code }
}

/// 龋齿清单的一行
private struct DecayRow: Identifiable {
    let code: Int
    let decay: ToothDecay
    var id: Int { code }
}

// MARK: - 单颗牙详情（标记脱落 / 记录龋齿）

private struct ToothDetailView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let code: Int

    @State private var pickDate = Date()
    @State private var showDecayEditor = false

    private var child: Child? { store.current }

    private var st: ToothState {
        guard let c = child else {
            return ToothState(def: ToothDef(code: code, name: "牙位 \(code)", earlyMonths: 0, lateMonths: 0),
                              status: .normal, fallenDate: nil)
        }
        return ToothEngine.state(code: code, child: c)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    decayCard
                    fallenCard
                }
                .padding(16)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("牙齿详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .sheet(isPresented: $showDecayEditor) {
                ToothDecayEditorView(startCode: code)
                    .environmentObject(store)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(st.status.softColor)
                    .frame(width: 58, height: 66)
                Text("\(st.def.code)")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(st.status.color)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(st.def.name).font(.system(size: 17, weight: .bold)).foregroundColor(Palette.ink)
                Text("FDI \(st.def.code) · 换牙期 \(st.def.windowLabel)")
                    .font(.system(size: 12.5)).foregroundColor(Palette.subtle)
                HStack(spacing: 6) {
                    Text(st.status.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(st.status.color)
                    if let d = st.decay {
                        Text("龋齿 · \(d.severityLabel)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DecayTone.color(d.severity))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(DecayTone.bg(d.severity))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
        }
        .cardStyle()
    }

    // MARK: 龋齿

    private var decayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🦷 龋齿（烂牙）")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.subtle)
                Spacer()
                if let d = st.decay {
                    Text("\(d.severityLabel) · \(ToothChartView.fmt.string(from: d.date))")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(DecayTone.color(d.severity))
                }
            }
            if let d = st.decay {
                if !d.note.isEmpty {
                    Text(d.note)
                        .font(.system(size: 12.5))
                        .foregroundColor(Palette.ink2)
                        .lineSpacing(3)
                }
                if d.needsVisit {
                    Text("中重度龋齿建议尽快看儿童口腔科，避免发展到牙髓炎或影响恒牙。")
                        .font(.system(size: 11.5))
                        .foregroundColor(Palette.warn)
                        .lineSpacing(3)
                }
                HStack(spacing: 10) {
                    Button {
                        showDecayEditor = true
                    } label: {
                        Text("修改记录")
                    }
                    .buttonStyle(PrimaryButtonStyle(filled: false))

                    Button {
                        store.setToothDecay(code, decay: nil)
                    } label: {
                        Text("清除")
                    }
                    .buttonStyle(PrimaryButtonStyle(filled: false))
                }
            } else {
                Text("有黑点、蛀洞、牙齿发黄发黑或孩子喊牙疼时，记一下这颗牙。")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.subtle)
                    .lineSpacing(3)
                Button {
                    showDecayEditor = true
                } label: {
                    Text("这颗牙有蛀牙 / 烂了")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .cardStyle()
    }

    // MARK: 脱落

    private var fallenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("脱落记录")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.subtle)
                Spacer()
            }
            if st.status == .fallen, let d = st.fallenDate {
                Text("脱落日期：" + ToothChartView.fmt.string(from: d))
                    .font(.system(size: 13)).foregroundColor(Palette.ok)
                Button {
                    store.setToothFallen(code, date: nil)
                    dismiss()
                } label: {
                    Text("恢复为「未脱落」")
                }
                .buttonStyle(PrimaryButtonStyle(filled: false))
            } else {
                DatePicker("脱落日期", selection: $pickDate, displayedComponents: .date)
                    .font(.system(size: 14))
                Button {
                    store.setToothFallen(code, date: pickDate)
                    dismiss()
                } label: {
                    Text("标记这颗牙已脱落")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .cardStyle()
    }
}

// MARK: - 记录龋齿（选牙 + 日期 + 程度 + 备注）

private struct ToothDecayEditorView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let startCode: Int?

    @State private var code: Int? = nil
    @State private var date = Date()
    @State private var severity = 1
    @State private var note = ""
    @State private var loaded = false

    private var decayMap: [Int: ToothDecay] { store.current?.teethDecay ?? [:] }
    private var fallenMap: [Int: Date] { store.current?.teethFallen ?? [:] }

    private var navTitle: String {
        if let c = code { return "记录龋齿 · \(c)" }
        return "记录龋齿"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    pickerCard
                    detailCard
                }
                .padding(16)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(code == nil)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let c = startCode {
                    select(c)
                }
            }
        }
    }

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("哪颗牙有龋齿（烂牙）？")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Spacer(minLength: 8)
                Text(selectedLabel)
                    .font(.system(size: 11.5, weight: code == nil ? .regular : .semibold))
                    .foregroundColor(code == nil ? Palette.subtle : Palette.purple)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            // 和「牙弓图」一样的拟真牙弓，直接点牙齿选，不用对编码
            ArchPickerView(codes: ToothDef.upperOrder,
                           isUpper: true,
                           selected: code,
                           decayed: Set(decayMap.keys),
                           fallen: Set(fallenMap.keys)) { select($0) }
            ArchPickerView(codes: ToothDef.lowerOrder,
                           isUpper: false,
                           selected: code,
                           decayed: Set(decayMap.keys),
                           fallen: Set(fallenMap.keys)) { select($0) }
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(Palette.bad).frame(width: 8, height: 8)
                    Text("已有记录").font(.system(size: 10.5)).foregroundColor(Palette.subtle)
                }
                HStack(spacing: 4) {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(Palette.ok)
                    Text("已脱落").font(.system(size: 10.5)).foregroundColor(Palette.subtle)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Palette.purple).frame(width: 10, height: 10)
                    Text("当前选择").font(.system(size: 10.5)).foregroundColor(Palette.subtle)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
        .cardStyle(padding: 12)
    }

    private var selectedLabel: String {
        guard let c = code, let def = ToothDef.all[c] else { return "点牙齿选择" }
        return "已选 \(c) \(def.name)"
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("发现日期", selection: $date, displayedComponents: .date)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 6) {
                Text("程度").font(.system(size: 12.5)).foregroundColor(Palette.subtle)
                Picker("程度", selection: $severity) {
                    Text("轻度").tag(1)
                    Text("中度").tag(2)
                    Text("重度").tag(3)
                }
                .pickerStyle(.segmented)
                Text(severityHint)
                    .font(.system(size: 11))
                    .foregroundColor(DecayTone.color(severity))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("备注（可选）").font(.system(size: 12.5)).foregroundColor(Palette.subtle)
                TextField("如：咬合面有洞，医生已补", text: $note, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(1...3)
                    .padding(10)
                    .background(Palette.hairlineSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
        }
        .cardStyle()
    }

    private var severityHint: String {
        switch severity {
        case 3: return "深龋 / 疼过 / 牙龈起包：尽快就诊，可能需要治疗或拔除"
        case 2: return "已经能看到蛀洞：建议 1~2 周内看牙医补牙"
        default: return "白斑、发黑但没有洞：加强刷牙 + 涂氟，观察变化"
        }
    }

    private func select(_ c: Int) {
        code = c
        if let d = decayMap[c] {
            date = d.date
            severity = d.severity
            note = d.note
        } else {
            date = Date()
            severity = 1
            note = ""
        }
    }

    private func save() {
        guard let c = code else { return }
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        store.setToothDecay(c, decay: ToothDecay(date: date, severity: severity, note: text))
        dismiss()
    }
}

// MARK: - 牙弓图（单颌）

struct ArchChartView: View {
    let states: [ToothState]
    let isUpper: Bool
    let onTap: (Int) -> Void

    /// 半椭圆弧参数：每张图独立（ry 固定，不随容器高度撑满，避免上下颌弧重叠）
    static let arcHeight: CGFloat = 210

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = Self.arcHeight
            let cx = w / 2
            let rx = w / 2 - 40
            let ry: CGFloat = 120
            // 上颌弧两端在下方（cy 大）、弧顶朝上；下颌相反
            let cy = isUpper ? h - 35 : 35

            ZStack {
                // 牙龈弧：按牙位椭圆（外扩 14pt）逐点连线，只画本颌那一段
                Path { p in
                    var first = true
                    var deg = 175.0
                    while deg >= 5 {
                        let t = deg * .pi / 180
                        let gx = cx + (rx + 14) * CGFloat(cos(t))
                        let gy = isUpper
                            ? cy - (ry + 14) * CGFloat(sin(t))
                            : cy + (ry + 14) * CGFloat(sin(t))
                        if first {
                            p.move(to: CGPoint(x: gx, y: gy))
                            first = false
                        } else {
                            p.addLine(to: CGPoint(x: gx, y: gy))
                        }
                        deg -= 5
                    }
                }
                .stroke(isUpper ? Color.pink.opacity(0.16) : Color.pink.opacity(0.13),
                        style: StrokeStyle(lineWidth: 28, lineCap: .round, lineJoin: .round))

                ForEach(Array(states.enumerated()), id: \.element.def.code) { idx, st in
                    // 从左端 175° 到右端 5°，均匀分布 10 颗
                    let theta = (175.0 - Double(idx) * 18.888) * .pi / 180
                    let x = cx + rx * CGFloat(cos(theta))
                    let y = isUpper
                        ? cy - ry * CGFloat(sin(theta))
                        : cy + ry * CGFloat(sin(theta))

                    ToothCell(st: st, isUpper: isUpper)
                        .position(x: x, y: y + (isUpper ? -9 : 9))
                        .onTapGesture { onTap(st.def.code) }
                }

                Text(isUpper ? "上颌（Maxillary）" : "下颌（Mandibular）")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Palette.subtle)
                    .position(x: cx, y: cy + (isUpper ? -46 : 46))
            }
        }
        .frame(height: Self.arcHeight)
    }
}

/// 一颗牙的图形（编号 + 牙冠）
struct ToothCell: View {
    let st: ToothState
    let isUpper: Bool

    var body: some View {
        VStack(spacing: 3) {
            if isUpper { numberLabel }
            glyph
            if !isUpper { numberLabel }
        }
    }

    private var numberLabel: some View {
        Text("\(st.def.code)")
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .foregroundColor(st.decay != nil ? Palette.bad : (st.status == .normal ? Palette.subtle : st.status.color))
    }

    private var glyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(st.status == .normal ? Palette.card : st.status.color)
            if st.status == .normal {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(st.decay != nil ? Palette.bad.opacity(0.6) : Palette.hairline,
                                  lineWidth: st.decay != nil ? 1.8 : 1.5)
            }
            glyphText
        }
        .frame(width: 30, height: 36)
        .overlay(alignment: .topTrailing) {
            // 龋齿标记：右上角一个小红点（不影响脱落/预警状态）
            if st.decay != nil {
                Circle()
                    .fill(Palette.bad)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.2))
                    .offset(x: 3, y: -3)
            }
        }
        .shadow(color: st.status == .warn || st.status == .overdue ? st.status.color.opacity(0.45) : .clear,
                radius: 7, y: 1)
    }

    @ViewBuilder private var glyphText: some View {
        switch st.status {
        case .fallen:
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
        case .warn, .overdue:
            Image(systemName: "exclamationmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
        case .normal:
            EmptyView()
        }
    }
}

// MARK: - 选牙用的牙弓图（与「牙弓图」同款排布，直接点牙齿选中）

struct ArchPickerView: View {
    let codes: [Int]
    let isUpper: Bool
    let selected: Int?
    let decayed: Set<Int>
    let fallen: Set<Int>
    let onTap: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = ArchChartView.arcHeight
            let cx = w / 2
            let rx = w / 2 - 40
            let ry: CGFloat = 120
            // 上颌弧顶朝上、两端在下；下颌相反（与「牙弓图」完全一致）
            let cy = isUpper ? h - 35 : 35
            let step = codes.count > 1 ? 170.0 / Double(codes.count - 1) : 0

            ZStack {
                // 牙龈弧
                Path { p in
                    var first = true
                    var deg = 175.0
                    while deg >= 5 {
                        let t = deg * .pi / 180
                        let gx = cx + (rx + 14) * CGFloat(cos(t))
                        let gy = isUpper
                            ? cy - (ry + 14) * CGFloat(sin(t))
                            : cy + (ry + 14) * CGFloat(sin(t))
                        if first {
                            p.move(to: CGPoint(x: gx, y: gy))
                            first = false
                        } else {
                            p.addLine(to: CGPoint(x: gx, y: gy))
                        }
                        deg -= 5
                    }
                }
                .stroke(isUpper ? Color.pink.opacity(0.16) : Color.pink.opacity(0.13),
                        style: StrokeStyle(lineWidth: 28, lineCap: .round, lineJoin: .round))

                ForEach(Array(codes.enumerated()), id: \.element) { idx, code in
                    let theta = (175.0 - Double(idx) * step) * .pi / 180
                    let x = cx + rx * CGFloat(cos(theta))
                    let y = isUpper
                        ? cy - ry * CGFloat(sin(theta))
                        : cy + ry * CGFloat(sin(theta))

                    pickerCell(code)
                        .position(x: x, y: y + (isUpper ? -9 : 9))
                        .onTapGesture { onTap(code) }
                }

                Text(isUpper ? "上颌（Maxillary）" : "下颌（Mandibular）")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Palette.subtle)
                    .position(x: cx, y: cy + (isUpper ? -46 : 46))
            }
        }
        .frame(height: ArchChartView.arcHeight)
    }

    private func pickerCell(_ code: Int) -> some View {
        let on = selected == code
        return VStack(spacing: 3) {
            if isUpper { number(code, on) }
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(on ? Palette.purple : Palette.card)
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(on ? Palette.purpleDeep : Palette.hairline, lineWidth: on ? 2 : 1.5)
                if fallen.contains(code) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(on ? .white : Palette.ok)
                }
            }
            .frame(width: 30, height: 36)
            .overlay(alignment: .topTrailing) {
                if decayed.contains(code) {
                    Circle()
                        .fill(Palette.bad)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.2))
                        .offset(x: 3, y: -3)
                }
            }
            .shadow(color: on ? Palette.purple.opacity(0.45) : .clear, radius: 8, y: 2)
            if !isUpper { number(code, on) }
        }
        .scaleEffect(on ? 1.06 : 1)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: on)
    }

    private func number(_ code: Int, _ on: Bool) -> some View {
        Text("\(code)")
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .foregroundColor(on ? Palette.purpleDeep : Palette.subtle)
    }
}
