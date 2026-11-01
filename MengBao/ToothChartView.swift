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

/// 一颗牙当前的综合状态（含脱落日期）
struct ToothState {
    let def: ToothDef
    let status: ToothStatus
    let fallenDate: Date?
}

// MARK: - 主视图

struct ToothChartView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let child: Child

    @State private var tab = 0
    @State private var selected: ToothSelection? = nil

    private var ageMonths: Int {
        Calendar.current.dateComponents([.month], from: child.birthDate, to: Date()).month ?? 0
    }

    private var fallenMap: [Int: Date] { child.teethFallen ?? [:] }

    private func state(of code: Int) -> ToothState {
        guard let def = ToothDef.all[code] else {
            return ToothState(def: ToothDef(code: code, name: "", earlyMonths: 0, lateMonths: 0), status: .normal, fallenDate: nil)
        }
        let fallen = fallenMap[code]
        let status: ToothStatus
        if fallen != nil {
            status = .fallen
        } else if ageMonths > def.lateMonths {
            status = .overdue
        } else if ageMonths >= def.earlyMonths - 6 {
            status = .warn
        } else {
            status = .normal
        }
        return ToothState(def: def, status: status, fallenDate: fallen)
    }

    private var allStates: [ToothState] { ToothDef.all.keys.sorted().map { state(of: $0) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    pickerBar
                    if tab == 0 { archSection } else { scheduleSection }
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
                let code = sel.code
                if let def = ToothDef.all[code] {
                    ToothDetailView(def: def, st: state(of: code)) { date in
                        markTooth(code, fallen: date)
                    }
                }
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
            tabButton("拟真牙弓图", index: 0)
            tabButton("换牙时间表", index: 1)
        }
        .background(Palette.hairlineSoft)
        .clipShape(Capsule())
        .padding(.horizontal, 16)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { tab = index }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: tab == index ? .semibold : .regular))
                .foregroundColor(tab == index ? Palette.ink : Palette.subtle)
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
        .buttonStyle(.plain)
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
        HStack(spacing: 14) {
            legendDot(ToothStatus.normal)
            legendDot(ToothStatus.warn)
            legendDot(ToothStatus.fallen)
            legendDot(ToothStatus.overdue)
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
                        if let d = st.fallenDate {
                            Text("已脱落 · " + Self.fmt.string(from: d))
                                .font(.system(size: 11.5)).foregroundColor(Palette.ok)
                        } else {
                            Text(st.status.label)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(st.status == .normal ? Palette.subtle : st.status.color)
                        }
                    }
                    .padding(.vertical, 10)
                    if code != codes.last {
                        Divider().background(Palette.hairlineSoft)
                    }
                }
            }
            .cardStyle(padding: 4)
        }
    }

    static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var hintCard: some View {
        Text("点击牙弓图上的任意一颗牙，可以记录脱落日期或恢复。换牙期为大多数孩子的普遍规律，个体差异 ±6 个月都属正常；「超期未换」建议请口腔科医生看看，确认恒牙萌出情况。")
            .font(.system(size: 11.5))
            .foregroundColor(Palette.subtle)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Palette.purpleTint)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
    }

    /// 标记 / 取消脱落
    private func markTooth(_ code: Int, fallen: Date?) {
        store.updateCurrent { c in
            var map = c.teethFallen ?? [:]
            if let d = fallen {
                map[code] = d
            } else {
                map.removeValue(forKey: code)
            }
            c.teethFallen = map.isEmpty ? nil : map
        }
    }
}

/// 牙弓图点选的包装
struct ToothSelection: Identifiable {
    let code: Int
    var id: Int { code }
}

// MARK: - 单颗牙详情（标记脱落 / 恢复）

private struct ToothDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let def: ToothDef
    let st: ToothState
    let onMark: (Date?) -> Void

    @State private var pickDate = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(st.status.softColor)
                            .frame(width: 58, height: 66)
                        Text("\(def.code)")
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundColor(st.status.color)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(def.name).font(.system(size: 17, weight: .bold)).foregroundColor(Palette.ink)
                        Text("FDI \(def.code) · 换牙期 \(def.windowLabel)")
                            .font(.system(size: 12.5)).foregroundColor(Palette.subtle)
                        Text(st.status.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(st.status.color)
                    }
                    Spacer()
                }
                .cardStyle()

                if st.status == .fallen, let d = st.fallenDate {
                    Text("记录的脱落日期：" + ToothChartView.fmt.string(from: d))
                        .font(.system(size: 13)).foregroundColor(Palette.ok)
                }

                if st.status == .fallen {
                    Button {
                        onMark(nil)
                        dismiss()
                    } label: {
                        Text("恢复为「未脱落」")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    DatePicker("脱落日期", selection: $pickDate, displayedComponents: .date)
                        .font(.system(size: 14))
                        .padding(14)
                        .cardStyle()
                    Button {
                        onMark(pickDate)
                        dismiss()
                    } label: {
                        Text("标记这颗牙已脱落")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("牙齿详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
        .presentationDetents([.height(360)])
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
            .foregroundColor(st.status == .normal ? Palette.subtle : st.status.color)
    }

    private var glyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(st.status == .normal ? Palette.card : st.status.color)
            if st.status == .normal {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1.5)
            }
            glyphText
        }
        .frame(width: 30, height: 36)
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
