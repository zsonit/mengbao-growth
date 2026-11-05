import SwiftUI
import UIKit

// MARK: - 生长曲线详情

struct GrowthDetailView: View {
    @EnvironmentObject private var store: Store
    @State private var metric: GrowthMetric = .height
    @State private var reminderDenied = false

    var body: some View {
        ScrollView {
            if let child = store.current {
                content(child)
            } else {
                EmptyHint(text: "先添加宝宝档案")
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("生长曲线")
        .navigationBarTitleDisplayMode(.inline)
        .alert("通知权限没打开", isPresented: $reminderDenied) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("稍后", role: .cancel) { }
        } message: {
            Text("要收到提醒，需要在「设置 → 通知 → 萌宝成长」里允许通知。")
        }
    }

    private func content(_ child: Child) -> some View {
        let last = child.latestRecord
        let evaluation = last.map { GrowthMath.evaluate(child: child, record: $0) }
        let velocity = GrowthMath.velocity(child: child)
        let prediction = last.flatMap { GrowthMath.predictedHeight(child: child, record: $0, settings: store.settings) }

        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(metric.rawValue)曲线").font(.system(size: 15.5, weight: .bold)).foregroundColor(Palette.ink)
                    Spacer()
                    Text(GrowthMath.ageText(from: child.birthDate)).font(.system(size: 12)).foregroundColor(Palette.subtle)
                }
                HStack(spacing: 8) {
                    ForEach(GrowthMetric.allCases) { m in
                        Button { metric = m } label: { ChipLabel(text: m.rawValue, selected: metric == m) }
                            .buttonStyle(SoftPressStyle())
                    }
                    Spacer()
                }
                GrowthChartView(child: child, metric: metric)
                    .frame(height: 252)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                HStack(spacing: 14) {
                    legend(color: Color(hex: 0xE0513A), dash: true, text: "P3 / P97")
                    legend(color: Color(hex: 0xE2A33C), dash: true, text: "P15 / P85")
                    legend(color: Palette.purple, dash: false, text: "P50")
                    legend(color: Palette.ok, dash: false, text: "实测")
                    Spacer(minLength: 4)
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.left.and.right")
                        Text("可滑动")
                    }
                    .font(.system(size: 10.5))
                    .foregroundColor(Palette.subtle)
                }
                .padding(.top, 2)

                NavigationLink {
                    GrowthTableView(initialMetric: metric)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tablecells")
                        Text("数据表格")
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(Palette.purple)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
            }
            .cardStyle()
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if let evaluation = evaluation, let last = last {
                VStack(alignment: .leading, spacing: 6) {
                    Text("身高 \(GrowthMath.percentileLabel(evaluation.heightPercentile ?? 50)) · \(evaluation.heightLevel?.label ?? "")")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Palette.purple)
                    Text(detailText(child: child, record: last, evaluation: evaluation))
                        .font(.system(size: 13))
                        .foregroundColor(Palette.ink2)
                        .lineSpacing(4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [Palette.purpleSoft, Palette.purpleTint], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.purple.opacity(0.22), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 12)
            } else {
                EmptyHint(text: "录入 1 条以上测量数据后显示评估")
            }

            reminderCard(child)

            VStack(spacing: 0) {
                SectionHeader(title: "变化与速度")
                VStack(spacing: 0) {
                    KVRow(key: "最近一次增长",
                          value: velocity.map { String(format: "%+.1f cm / %d 天", $0.delta, $0.days) } ?? "—")
                    Divider().background(Palette.hairlineSoft)
                    KVRow(key: "年化生长速度",
                          value: velocity.map { String(format: "%.1f cm/年", $0.perYear) } ?? "—")
                    Divider().background(Palette.hairlineSoft)
                    KVRow(key: "速度评价",
                          value: velocity.map { GrowthMath.velocityComment(child: child, perYear: $0.perYear) } ?? "数据不足")
                }
                .cardStyle()
                .padding(.horizontal, 16)
            }

            VStack(spacing: 0) {
                SectionHeader(title: "18 岁身高预测")
                VStack(spacing: 0) {
                    KVRow(key: "预测值",
                          value: prediction.map { "\(Int($0.value.rounded())) cm（\(Int($0.low.rounded()))–\(Int($0.high.rounded()))）" } ?? "需先记录身高",
                          valueColor: Palette.purple)
                    Divider().background(Palette.hairlineSoft)
                    KVRow(key: "预测方法", value: prediction?.method ?? "—")
                    Divider().background(Palette.hairlineSoft)
                    KVRow(key: "父母身高",
                          value: (store.settings.fatherHeight != nil && store.settings.motherHeight != nil)
                            ? "\(Int(store.settings.fatherHeight!)) / \(Int(store.settings.motherHeight!)) cm"
                            : "未填写（在「我的」中补全）")
                    Text("预测误差约 ±5cm，仅作趋势参考。青春期发育节奏个体差异大，不建议据此做任何医疗决定。")
                        .font(.system(size: 12))
                        .foregroundColor(Palette.subtle)
                        .lineSpacing(3)
                        .padding(.top, 10)
                }
                .cardStyle()
                .padding(.horizontal, 16)
            }

            HintBlock(text: "参考带按性别与月龄逐点计算：0–5 岁用 WHO 标准（LMS 法），5–7 岁用中国 7 岁以下参照标准中位数，7–18 岁用 WS/T 423 等级评价表。测量方式（脱鞋、同一台秤、晨起空腹）对曲线影响很大，看趋势比看单点更重要。")
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 28)
        }
    }

    private func detailText(child: Child, record: GrowthRecord, evaluation: Evaluation) -> String {
        var parts: [String] = []
        if let h = record.height, let p = evaluation.heightPercentile {
            parts.append("\(GrowthMath.dateString(record.date)) 测 \(String(format: "%.1f", h))cm，超过同龄 \(Int(p.rounded()))% 的孩子。")
        }
        if let level = evaluation.heightLevel, level.tone != .ok {
            parts.append(level.desc)
        }
        if let wp = evaluation.weightPercentile, let bmi = evaluation.bmi {
            parts.append("体重 \(GrowthMath.percentileLabel(wp))，BMI \(String(format: "%.1f", bmi))（\(GrowthMath.percentileLabel(evaluation.bmiPercentile ?? 50))）。")
        }
        parts.append("参考：\(evaluation.source)。")
        return parts.joined(separator: "\n")
    }

    private func legend(color: Color, dash: Bool, text: String) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 14, height: dash ? 1.4 : 2.2)
                .opacity(dash ? 0.85 : 1)
            Text(text).font(.system(size: 10.5)).foregroundColor(Palette.subtle)
        }
    }

    // MARK: - 定期测量提醒

    private struct IntervalPreset: Identifiable {
        let days: Int
        let label: String
        var id: Int { days }
    }

    private static let intervalPresets: [IntervalPreset] = [
        IntervalPreset(days: 7, label: "一周"),
        IntervalPreset(days: 14, label: "两周"),
        IntervalPreset(days: 30, label: "一个月"),
        IntervalPreset(days: 90, label: "三个月")
    ]

    private static let reminderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    @ViewBuilder
    private func reminderCard(_ child: Child) -> some View {
        let s = store.settings
        VStack(spacing: 0) {
            SectionHeader(title: "定期测量提醒")
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { s.growthReminderOn },
                    set: { on in
                        if on {
                            NotificationManager.shared.ensureAuthorized { ok in
                                if !ok { reminderDenied = true }
                            }
                        }
                        store.setGrowthReminder(on: on)
                    })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("到点提醒我量身高体重").font(.system(size: 14)).foregroundColor(Palette.ink)
                        Text("本机通知，不联网；关掉就不再提醒")
                            .font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                    }
                }
                .tint(Palette.purple)

                if s.growthReminderOn {
                    // 间隔（常用档位）
                    HStack(spacing: 8) {
                        ForEach(Self.intervalPresets) { preset in
                            Button {
                                store.setGrowthReminder(on: true, days: preset.days)
                            } label: {
                                ChipLabel(text: preset.label, selected: s.growthReminderDays == preset.days)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                        Spacer(minLength: 0)
                    }

                    // 自定义天数
                    HStack {
                        Text("自定义间隔").font(.system(size: 13.5)).foregroundColor(Palette.ink2)
                        Spacer()
                        Stepper(value: Binding(
                            get: { s.growthReminderDays },
                            set: { store.setGrowthReminder(on: true, days: $0) }),
                                in: 1...180) {
                            Text("\(s.growthReminderDays) 天")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Palette.purple)
                        }
                        .fixedSize()
                    }

                    // 提醒时间
                    HStack {
                        Text("提醒时间").font(.system(size: 13.5)).foregroundColor(Palette.ink2)
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: {
                                Calendar.current.date(bySettingHour: s.growthReminderHour,
                                                      minute: s.growthReminderMinute,
                                                      second: 0, of: Date()) ?? Date()
                            },
                            set: { d in
                                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                                store.setGrowthReminder(on: true, hour: c.hour, minute: c.minute)
                            }), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    }

                    // 上次 / 下次
                    VStack(alignment: .leading, spacing: 4) {
                        if let last = child.latestRecord?.date {
                            Text("上次测量：\(GrowthMath.dateString(last))")
                        } else {
                            Text("还没有测量记录，第一次提醒从今天起算")
                        }
                        if let next = store.nextGrowthReminderDate(for: child) {
                            Text("下次提醒：\(Self.reminderFormatter.string(from: next))")
                                .foregroundColor(Palette.purple)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Palette.subtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Palette.purpleTint)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Text("开启后按「上次测量日期 + 间隔」自动计算，到点收到本机通知。0–3 岁建议一个月量一次。")
                        .font(.system(size: 12))
                        .foregroundColor(Palette.subtle)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .cardStyle()
            .padding(.horizontal, 16)
        }
        .padding(.top, 4)
    }
}

// MARK: - 记录编辑

struct RecordEditorView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let child: Child
    let record: GrowthRecord?

    @State private var date: Date
    @State private var height: String
    @State private var weight: String
    @State private var foot: String
    @State private var head: String
    @State private var note: String
    @State private var errorMessage: String?

    init(child: Child, record: GrowthRecord?) {
        self.child = child
        self.record = record
        _date = State(initialValue: record?.date ?? Date())
        _height = State(initialValue: record?.height.map { String(format: "%.1f", $0) } ?? "")
        _weight = State(initialValue: record?.weight.map { String(format: "%.1f", $0) } ?? "")
        _foot = State(initialValue: record?.footLength.map { String(format: "%.1f", $0) } ?? "")
        _head = State(initialValue: record?.headCirc.map { String(format: "%.1f", $0) } ?? "")
        _note = State(initialValue: record?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 10) {
                        DatePicker("测量日期", selection: $date, displayedComponents: .date)
                            .font(.system(size: 14))
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(Palette.purpleTint)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                        HStack(spacing: 10) {
                            numberField(title: "身高", text: $height, unit: "cm")
                            numberField(title: "体重", text: $weight, unit: "kg")
                        }
                        HStack(spacing: 10) {
                            numberField(title: "脚长", text: $foot, unit: "cm")
                            numberField(title: "头围", text: $head, unit: "cm")
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("备注").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                            TextField("晨起空腹 / 换季衣服尺码", text: $note)
                                .font(.system(size: 15))
                        }
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.purpleTint)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                        Text("身高脱鞋靠墙站直量；体重建议晨起空腹、同一台秤。测量方式不同会让曲线跳动，别误读成生长异常。")
                            .font(.system(size: 12)).foregroundColor(Palette.subtle).lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .cardStyle()

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13)).foregroundColor(Palette.bad)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Palette.badBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(record == nil ? "保存" : "保存修改") { save() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle(record == nil ? "记录生长数据" : "修改记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func numberField(title: String, text: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 11.5)).foregroundColor(Palette.subtle)
            HStack(spacing: 4) {
                TextField("0.0", text: text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .semibold))
                Text(unit).font(.system(size: 12.5)).foregroundColor(Palette.subtle)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.purpleTint)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func save() {
        let h = Double(height.replacingOccurrences(of: "，", with: "."))
        let w = Double(weight.replacingOccurrences(of: "，", with: "."))
        let f = Double(foot.replacingOccurrences(of: "，", with: "."))
        let hc = Double(head.replacingOccurrences(of: "，", with: "."))

        guard h != nil || w != nil else {
            errorMessage = "身高和体重至少填一项"
            return
        }
        if let h = h, h < 30 || h > 220 {
            errorMessage = "身高数值看起来不太对"
            return
        }
        if let w = w, w < 1 || w > 150 {
            errorMessage = "体重数值看起来不太对"
            return
        }
        if date > Date() {
            errorMessage = "测量日期不能晚于今天"
            return
        }

        var newRecord = record ?? GrowthRecord(date: date, height: nil, weight: nil, footLength: nil, headCirc: nil)
        newRecord.date = date
        newRecord.height = h
        newRecord.weight = w
        newRecord.footLength = f
        newRecord.headCirc = hc
        newRecord.note = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if record == nil {
            store.addRecord(newRecord)
        } else {
            store.updateRecord(newRecord)
        }
        dismiss()
    }
}

// MARK: - 鞋服尺码

struct SizeEditorView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let child: Child

    @State private var date = Date()
    @State private var foot: String = ""
    @State private var height: String = ""
    @State private var shoulder: String = ""
    @State private var waist: String = ""
    @State private var hip: String = ""
    @State private var thigh: String = ""
    @State private var calf: String = ""
    @State private var legLength: String = ""
    @State private var armLength: String = ""
    @State private var topLength: String = ""
    @State private var sleeve: String = ""
    @State private var pantsLength: String = ""
    @State private var shoeSize: String = ""
    @State private var shoeInner: String = ""
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    DatePicker("记录日期", selection: $date, displayedComponents: .date)
                        .font(.system(size: 14))
                        .padding(.horizontal, 13).padding(.vertical, 8)
                        .background(Palette.purpleTint)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    // 身体尺寸
                    VStack(alignment: .leading, spacing: 10) {
                        Text("身体尺寸").font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.subtle)
                        HStack(spacing: 10) {
                            inputField(title: "身高", text: $height, unit: "cm")
                            inputField(title: "肩宽", text: $shoulder, unit: "cm")
                        }
                        HStack(spacing: 10) {
                            inputField(title: "腰围", text: $waist, unit: "cm")
                            inputField(title: "臀围", text: $hip, unit: "cm")
                        }
                        HStack(spacing: 10) {
                            inputField(title: "大腿围", text: $thigh, unit: "cm")
                            inputField(title: "小腿围", text: $calf, unit: "cm")
                        }
                        HStack(spacing: 10) {
                            inputField(title: "腿长", text: $legLength, unit: "cm")
                            inputField(title: "手臂长", text: $armLength, unit: "cm")
                        }
                    }
                    .cardStyle()

                    // 脚与鞋
                    VStack(alignment: .leading, spacing: 10) {
                        Text("脚与鞋").font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.subtle)
                        HStack(spacing: 10) {
                            inputField(title: "脚长", text: $foot, unit: "cm")
                            inputField(title: "穿鞋码数", text: $shoeSize, unit: "码")
                        }
                        inputField(title: "鞋内长", text: $shoeInner, unit: "cm")
                    }
                    .cardStyle()

                    // 衣物尺寸
                    VStack(alignment: .leading, spacing: 10) {
                        Text("衣物尺寸").font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.subtle)
                        HStack(spacing: 10) {
                            inputField(title: "衣长", text: $topLength, unit: "cm")
                            inputField(title: "袖长", text: $sleeve, unit: "cm")
                        }
                        inputField(title: "裤长", text: $pantsLength, unit: "cm")
                    }
                    .cardStyle()

                    let size = GrowthMath.shoeSize(foot: Double(foot), height: Double(height))
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("自动换算").font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.subtle)
                            Spacer()
                            Text("填脚长/身高即时更新").font(.system(size: 11)).foregroundColor(Palette.subtle)
                        }
                        .padding(.bottom, 6)
                        if size.cn == nil && size.top == nil {
                            Text("填写脚长或身高后自动换算").font(.system(size: 13)).foregroundColor(Palette.subtle)
                        } else {
                            if let cn = size.cn, let eu = size.eu, let inner = size.inner {
                                KVRow(key: "中国码", value: "\(cn) 码")
                                Divider().background(Palette.hairlineSoft)
                                KVRow(key: "欧码 FR", value: "\(eu)")
                                Divider().background(Palette.hairlineSoft)
                                KVRow(key: "建议内长", value: String(format: "%.1f cm", inner))
                            }
                            if let top = size.top, let pant = size.pant, let hip = size.hip {
                                Divider().background(Palette.hairlineSoft)
                                KVRow(key: "上衣建议", value: top)
                                Divider().background(Palette.hairlineSoft)
                                KVRow(key: "裤子建议", value: "\(pant) · \(hip)")
                            }
                        }
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 3) {
                        Text("备注").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                        TextField("如：换季买的运动鞋", text: $note).font(.system(size: 15))
                    }
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.purpleTint)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    Text("鞋码为换算建议：中国码 ≈ 脚长×2−10，欧码 ≈ 脚长×1.5+2。不同品牌版型差异大，买鞋建议预留 0.5–1cm 活动空间。所有项都可留空，只填需要的。")
                        .font(.system(size: 12)).foregroundColor(Palette.subtle).lineSpacing(3)

                    Button("保存尺码记录") {
                        let values = [foot, height, shoulder, waist, hip, thigh, calf,
                                      legLength, armLength, topLength, sleeve, pantsLength, shoeInner]
                        guard values.contains(where: { Double($0) != nil }) || Int(shoeSize) != nil else { return }
                        store.addSize(SizeRecord(
                            date: date,
                            footLength: Double(foot),
                            height: Double(height),
                            shoulder: Double(shoulder),
                            waist: Double(waist),
                            hip: Double(hip),
                            thigh: Double(thigh),
                            calf: Double(calf),
                            legLength: Double(legLength),
                            armLength: Double(armLength),
                            topLength: Double(topLength),
                            sleeve: Double(sleeve),
                            pantsLength: Double(pantsLength),
                            shoeSize: Int(shoeSize),
                            shoeInner: Double(shoeInner),
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines)))
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("鞋服尺码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .onAppear {
                // 打开尺码页先跟云端对一次：另一端刚改的尺码不用等轮询就能看到
                SyncManager.shared.requestSync()
                // 只取「有内容」的最新一条；同一天有多条时取字段最全的那条（和安卓一致）
                let latest = child.sizes.filter { $0.hasContent }.max { a, b in
                    if a.date != b.date { return a.date < b.date }
                    return a.filledCount < b.filledCount
                }
                if foot.isEmpty, let last = child.latestRecord?.footLength ?? latest?.footLength {
                    foot = String(format: "%.1f", last)
                }
                if height.isEmpty, let h = child.latestRecord?.height ?? latest?.height {
                    height = String(format: "%.1f", h)
                }
                if let last = latest {
                    if shoeSize.isEmpty, let v = last.shoeSize { shoeSize = "\(v)" }
                    if shoeInner.isEmpty, let v = last.shoeInner { shoeInner = String(format: "%.1f", v) }
                    if shoulder.isEmpty, let v = last.shoulder { shoulder = String(format: "%.1f", v) }
                    if waist.isEmpty, let v = last.waist { waist = String(format: "%.1f", v) }
                    if hip.isEmpty, let v = last.hip { hip = String(format: "%.1f", v) }
                    if thigh.isEmpty, let v = last.thigh { thigh = String(format: "%.1f", v) }
                    if calf.isEmpty, let v = last.calf { calf = String(format: "%.1f", v) }
                    if legLength.isEmpty, let v = last.legLength { legLength = String(format: "%.1f", v) }
                    if armLength.isEmpty, let v = last.armLength { armLength = String(format: "%.1f", v) }
                    if topLength.isEmpty, let v = last.topLength { topLength = String(format: "%.1f", v) }
                    if sleeve.isEmpty, let v = last.sleeve { sleeve = String(format: "%.1f", v) }
                    if pantsLength.isEmpty, let v = last.pantsLength { pantsLength = String(format: "%.1f", v) }
                }
            }
        }
    }

    private func inputField(title: String, text: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 11.5)).foregroundColor(Palette.subtle)
            HStack(spacing: 4) {
                TextField("0.0", text: text).keyboardType(.decimalPad).font(.system(size: 16, weight: .semibold))
                Text(unit).font(.system(size: 12.5)).foregroundColor(Palette.subtle)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.purpleTint)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

// MARK: - 待办

struct TodoEditorView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let child: Child

    @State private var title = ""
    @State private var hasDue = false
    @State private var due = Date()
    @State private var addedHint: String? = nil
    // 按住就地说话：不跳第二个页面，松手直接拆成待办
    @StateObject private var mic = SpeechRecorder()
    @State private var micHolding = false
    @State private var fingerDown = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("要做的事").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                            TextField("如：预约 18 月龄体检", text: $title).font(.system(size: 15))
                        }
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.purpleTint)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }

                    if let hint = addedHint {
                        Text(hint)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(Palette.ok)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }


                    Toggle("设置截止日期", isOn: $hasDue).font(.system(size: 14))
                    if hasDue {
                        DatePicker("截止日期", selection: $due, displayedComponents: .date)
                            .font(.system(size: 14))
                        HStack(spacing: 5) {
                            Image(systemName: "bell.badge.fill").font(.system(size: 10))
                            Text(store.settings.todoReminderOn
                                 ? "到期前一天 20:00、当天 9:00 各提醒一次"
                                 : "待办提醒已关闭（可在「我的 → 提醒」里打开）")
                                .font(.system(size: 11.5))
                        }
                        .foregroundColor(store.settings.todoReminderOn ? Palette.purple : Palette.subtle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                    }

                    Button("添加") {
                        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        if hasDue { NotificationManager.shared.ensureAuthorized() }
                        store.addTodo(TodoItem(title: text, due: hasDue ? due : nil))
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if !currentTodos.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("已存在的待办").font(.system(size: 13, weight: .semibold)).foregroundColor(Palette.subtle)
                            ForEach(currentTodos) { todo in
                                HStack {
                                    Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(todo.done ? Palette.ok : Palette.subtle)
                                    Text(todo.title).font(.system(size: 13.5))
                                        .foregroundColor(todo.done ? Palette.subtle : Palette.ink)
                                    Spacer()
                                    if let due = todo.due {
                                        Text(shortDue(due))
                                            .font(.system(size: 11))
                                            .foregroundColor(Palette.purple)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .cardStyle()
                    }
                }
                .padding(16)
            }
            .background(Palette.background.ignoresSafeArea())
            // 语音按钮钉在页面底部中间（和主页一致）：按住说话，不跳页
            .safeAreaInset(edge: .bottom, spacing: 0) { voiceBottomBar }
            .navigationTitle("新增待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulseTick = true }
        }
        .onDisappear {
            mic.stop()
            micHolding = false
        }
    }

    // MARK: 底部语音条（按住说话）

    private var voiceBottomBar: some View {
        VStack(spacing: 10) {
            // 按住时的实时转写
            if micHolding, !mic.transcript.isEmpty {
                Text(mic.transcript + " …")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.purple)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Text(micHolding ? "我在听… 说完松手，几件都行" : "按住麦克风说话，一次几件都行，自动拆成多条")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(micHolding ? Palette.purple : Palette.subtle)

            ZStack {
                if micHolding {
                    Circle()
                        .stroke(Palette.purple.opacity(0.35), lineWidth: 2)
                        .frame(width: 58, height: 58)
                        .scaleEffect(pulseTick ? 1.3 : 1.0)
                        .opacity(pulseTick ? 0.2 : 0.8)
                }
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0xFF8FB1), Color(hex: 0xA97BFF)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                    .shadow(color: Color(hex: 0xA97BFF).opacity(micHolding ? 0.55 : 0.35), radius: micHolding ? 14 : 9, y: 5)
                Image(systemName: micHolding ? "waveform" : "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(micHolding ? 1.08 : 1)
            .animation(.easeInOut(duration: 0.18), value: micHolding)
            .contentShape(Circle())
            .simultaneousGesture(holdToTalkGesture)
            .accessibilityLabel("按住语音添加待办")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Palette.background.ignoresSafeArea())
    }

    @State private var pulseTick = false

    // MARK: 按住说话（就地录音，不跳页）

    private var holdToTalkGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !fingerDown else { return }
                fingerDown = true
                beginHold()
            }
            .onEnded { _ in
                fingerDown = false
                endHold()
            }
    }

    private func beginHold() {
        guard !micHolding else { return }
        addedHint = nil
        mic.requestPermission { ok in
            guard ok else {
                addedHint = "没有麦克风/语音识别权限，去 设置 → 隐私与安全性 里打开"
                return
            }
            // 权限回调是异步的：手指已抬起（只是点了一下）就不启动录音，防止卡在录音态
            guard fingerDown else { return }
            mic.start()
            if let m = mic.message {
                addedHint = m
                return
            }
            micHolding = true
        }
    }

    private func endHold() {
        guard micHolding else { return }
        micHolding = false
        mic.stop()
        let said = mic.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard said.count >= 2 else {
            addedHint = "没听清说什么，按住再说一次"
            return
        }
        let parsed = TodoParser.parse(said)
        if parsed.isEmpty {
            // 没拆出待办：把原话填进输入框，改一改再点添加
            title = said
            addedHint = "这句没拆出待办，原话已填到上面，改一改再点「添加」"
        } else {
            let items = parsed
                .map { TodoItem(title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines), due: $0.due) }
                .filter { !$0.title.isEmpty }
            guard !items.isEmpty else {
                title = said
                addedHint = "这句没拆出待办，原话已填到上面，改一改再点「添加」"
                return
            }
            store.addTodos(items)
            if items.contains(where: { $0.due != nil }) {
                NotificationManager.shared.ensureAuthorized()
            }
            let names = items.prefix(3).map { $0.title }.joined(separator: "、")
            let more = items.count > 3 ? " 等 \(items.count) 条" : ""
            addedHint = "已加入 \(items.count) 条：\(names)\(more)"
        }
    }

    /// 直接读 store，语音加完列表立刻刷新（外面传进来的 child 是快照）
    private var currentTodos: [TodoItem] {
        store.current?.todos ?? []
    }

    private func shortDue(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if days == 0 { return "今天" }
        if days == 1 { return "明天" }
        if days == 2 { return "后天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }
}

// MARK: - 阶段重点

struct StageSheet: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let child: Child

    /// 直接读 store，加入后 ⊕ 立即变 ✓（外面传进来的 child 是快照）
    private var currentTodos: [TodoItem] {
        store.current?.todos ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(child.name) · \(GrowthMath.ageText(from: child.birthDate))")
                        .font(.system(size: 13)).foregroundColor(Palette.subtle)
                    ForEach(GrowthMath.milestones(for: child), id: \.self) { item in
                        // 实时读待办列表：已加入显示 ✓，避免重复添加且无反馈
                        let added = currentTodos.contains { $0.title == item }
                        HStack(alignment: .top, spacing: 8) {
                            Text(item).font(.system(size: 14)).foregroundColor(Palette.ink)
                            Spacer(minLength: 8)
                            Button {
                                guard !added else { return }
                                store.addTodo(TodoItem(title: item))
                            } label: {
                                Image(systemName: added ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.system(size: 19))
                                    .foregroundColor(added ? Palette.ok : Palette.purple)
                                    .frame(width: 38, height: 38)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(SoftPressStyle())
                            .disabled(added)
                        }
                        .padding(14)
                        .background(Palette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.hairline, lineWidth: 1))
                    }
                    HintBlock(text: "以上为通用育儿提示，早产儿、低出生体重儿或有基础疾病的孩子请以儿保医生的建议为准。")
                }
                .padding(16)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("阶段重点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }
}
