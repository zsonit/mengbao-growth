import SwiftUI

// MARK: - 生长曲线详情

struct GrowthDetailView: View {
    @EnvironmentObject private var store: Store
    @State private var metric: GrowthMetric = .height

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
                            .buttonStyle(.plain)
                    }
                    Spacer()
                }
                GrowthChartView(child: child, metric: metric)
                    .frame(height: 236)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                HStack(spacing: 14) {
                    legend(color: Color(hex: 0xE0513A), dash: true, text: "P3 / P97")
                    legend(color: Color(hex: 0xE2A33C), dash: true, text: "P15 / P85")
                    legend(color: Palette.purple, dash: false, text: "P50")
                    legend(color: Palette.ok, dash: false, text: "实测")
                }
                .padding(.top, 2)
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
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 10) {
                        DatePicker("记录日期", selection: $date, displayedComponents: .date)
                            .font(.system(size: 14))
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(Palette.purpleTint)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        HStack(spacing: 10) {
                            inputField(title: "脚长", text: $foot, unit: "cm")
                            inputField(title: "身高", text: $height, unit: "cm")
                        }
                    }
                    .cardStyle()

                    let size = GrowthMath.shoeSize(foot: Double(foot), height: Double(height))
                    VStack(alignment: .leading, spacing: 0) {
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

                    Text("鞋码为换算建议：中国码 ≈ 脚长×2−10，欧码 ≈ 脚长×1.5+2。不同品牌版型差异大，买鞋建议预留 0.5–1cm 活动空间。")
                        .font(.system(size: 12)).foregroundColor(Palette.subtle).lineSpacing(3)

                    Button("保存尺码记录") {
                        let f = Double(foot)
                        let h = Double(height)
                        guard f != nil || h != nil else { return }
                        store.addSize(SizeRecord(date: date, footLength: f, height: h,
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
                if foot.isEmpty, let last = child.latestRecord?.footLength { foot = String(format: "%.1f", last) }
                if height.isEmpty, let h = child.latestRecord?.height { height = String(format: "%.1f", h) }
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("要做的事").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                        TextField("如：预约 18 月龄体检", text: $title).font(.system(size: 15))
                    }
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.purpleTint)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    Toggle("设置截止日期", isOn: $hasDue).font(.system(size: 14))
                    if hasDue {
                        DatePicker("截止日期", selection: $due, displayedComponents: .date)
                            .font(.system(size: 14))
                    }

                    Button("添加") {
                        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        store.addTodo(TodoItem(title: text, due: hasDue ? due : nil))
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if !child.todos.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("已存在的待办").font(.system(size: 13, weight: .semibold)).foregroundColor(Palette.subtle)
                            ForEach(child.todos) { todo in
                                HStack {
                                    Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(todo.done ? Palette.ok : Palette.subtle)
                                    Text(todo.title).font(.system(size: 13.5))
                                        .foregroundColor(todo.done ? Palette.subtle : Palette.ink)
                                    Spacer()
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
            .navigationTitle("新增待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }
}

// MARK: - 阶段重点

struct StageSheet: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let child: Child

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(child.name) · \(GrowthMath.ageText(from: child.birthDate))")
                        .font(.system(size: 13)).foregroundColor(Palette.subtle)
                    ForEach(GrowthMath.milestones(for: child), id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text(item).font(.system(size: 14)).foregroundColor(Palette.ink)
                            Spacer(minLength: 8)
                            Button {
                                if !child.todos.contains(where: { $0.title == item }) {
                                    store.addTodo(TodoItem(title: item))
                                }
                            } label: {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(Palette.purple)
                            }
                            .buttonStyle(.plain)
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
