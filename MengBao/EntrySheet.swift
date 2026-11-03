import SwiftUI

// MARK: - 通用底部弹层录入

/// 首页 / 喂养页点任意快捷入口都走这里。
/// 用法：.sheet(item: $entry) { EntrySheet(entry: $0) { entry = nil } }
struct EntrySheet: View {
    @EnvironmentObject private var store: Store

    let entry: QuickEntry
    let onClose: () -> Void

    // 统一的时间（日期 + 时间共用一份 Date，两个 DatePicker 各改一半）
    @State private var date = Date()
    @State private var note = ""

    // 各类型各自的值
    @State private var amount: Double = 150          // 瓶喂 / 吸奶 ml
    @State private var side = "左"
    @State private var minutes: Double = 15          // 亲喂 / 睡眠
    @State private var diaperKind = "小便"
    @State private var food = ""
    @State private var grams: Double = 0             // 辅食克数，0 表示不记
    @State private var supplement = ""
    @State private var temperature: Double = 36.5
    @State private var weight: Double = 3.5
    @State private var height: Double = 50
    @State private var head: Double = 40
    @State private var customText = ""

    var body: some View {
        VStack(spacing: 0) {
            // 顶部灰色拖拽条
            Capsule()
                .fill(Palette.hairline)
                .frame(width: 38, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 10)

            header

            ScrollView {
                VStack(spacing: 14) {
                    content
                    dateRows
                    if showsExtraNote { noteField }
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 8)
            }

            // 保存按钮固定在弹层底部，不随内容滚动，半屏高度也不会被挡住
            Button("保存") { save() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(Palette.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear { prepare() }
    }

    // MARK: 头部

    private var header: some View {
        HStack(spacing: 8) {
            Text(entry.icon).font(.system(size: 20))
            Text(entry.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Palette.ink)
            Spacer()
            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Palette.subtle.opacity(0.55))
            }
            .buttonStyle(SoftPressStyle())
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    // MARK: 按类型分支

    @ViewBuilder
    private var content: some View {
        switch entry.kind {
        case "bottle", "pumping":
            VStack(spacing: 12) {
                bigValue(String(format: "%.0f", amount), unit: "ml")
                RulerPicker(value: $amount, range: 0...300, step: 5, format: "%.0f", unit: "ml")
                numberChips(EntryPresets.milkAmounts, format: "%.0f", unit: "ml", current: amount) { amount = $0 }
            }
            .cardStyle()

        case "breast":
            VStack(spacing: 12) {
                Picker("", selection: $side) {
                    Text("左侧").tag("左")
                    Text("右侧").tag("右")
                }
                .pickerStyle(.segmented)

                bigValue("\(Int(minutes))", unit: "分钟")
                RulerPicker(value: $minutes, range: 0...60, step: 1, format: "%.0f", unit: "分钟")
            }
            .cardStyle()

        case "sleep":
            VStack(spacing: 12) {
                bigValue("\(Int(minutes))", unit: "分钟")
                RulerPicker(value: $minutes, range: 0...240, step: 5, format: "%.0f", unit: "分钟")
                numberChips(EntryPresets.sleepMinutes.map { Double($0) }, format: "%.0f", unit: "分钟", current: minutes) { minutes = $0 }
            }
            .cardStyle()

        case "diaper":
            VStack(alignment: .leading, spacing: 12) {
                textChips(EntryPresets.diaperKinds, current: diaperKind) { diaperKind = $0 }
                Text("小便 / 大便 / 混合，按实际情况选一个就行。")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.subtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()

        case "solid":
            VStack(alignment: .leading, spacing: 12) {
                simpleField(title: "吃了什么", placeholder: "吃了什么？例如 南瓜泥", text: $food)
                textChips(EntryPresets.foods, current: food) { food = $0 }
                Divider().background(Palette.hairlineSoft)
                Text("大概吃了多少（可选）")
                    .font(.system(size: 11.5))
                    .foregroundColor(Palette.subtle)
                RulerPicker(value: $grams, range: 0...300, step: 10, format: "%.0f", unit: "g")
            }
            .cardStyle()

        case "supplement":
            VStack(alignment: .leading, spacing: 12) {
                simpleField(title: "补了什么", placeholder: "补了什么？", text: $supplement)
                textChips(EntryPresets.supplements, current: supplement) { supplement = $0 }
            }
            .cardStyle()

        case "temp":
            VStack(spacing: 12) {
                bigValue(String(format: "%.1f", temperature), unit: "℃", color: tempAccent)
                RulerPicker(value: $temperature, range: 34...42, step: 0.1,
                            format: "%.1f", unit: "℃", accent: tempAccent)
                Text(tempHint)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(tempAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cardStyle()

        case "weight":
            VStack(spacing: 12) {
                bigValue(String(format: "%.2f", weight), unit: "kg")
                RulerPicker(value: $weight, range: 0.5...60, step: 0.05, format: "%.2f", unit: "kg")
            }
            .cardStyle()

        case "height":
            VStack(spacing: 12) {
                bigValue(String(format: "%.1f", height), unit: "cm")
                RulerPicker(value: $height, range: 30...160, step: 0.1, format: "%.1f", unit: "cm")
            }
            .cardStyle()

        case "head":
            VStack(spacing: 12) {
                bigValue(String(format: "%.1f", head), unit: "cm")
                RulerPicker(value: $head, range: 25...60, step: 0.1, format: "%.1f", unit: "cm")
            }
            .cardStyle()

        default:
            VStack(alignment: .leading, spacing: 12) {
                simpleField(title: entry.title, placeholder: "记点什么…", text: $customText)
            }
            .cardStyle()
        }
    }

    // MARK: 小部件

    private func bigValue(_ text: String, unit: String, color: Color = Palette.ink) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(text)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(unit)
                .font(.system(size: 13))
                .foregroundColor(Palette.subtle)
        }
        .frame(maxWidth: .infinity)
    }

    private func numberChips(_ values: [Double], format: String, unit: String = "",
                             current: Double, onTap: @escaping (Double) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { v in
                    Button { onTap(v) } label: {
                        ChipLabel(text: String(format: format, v) + unit,
                                  selected: abs(current - v) < 0.001)
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func textChips(_ values: [String], current: String, onTap: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { v in
                    Button { onTap(v) } label: {
                        ChipLabel(text: v, selected: current == v)
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func simpleField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 11.5)).foregroundColor(Palette.subtle)
            TextField(placeholder, text: text).font(.system(size: 15))
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.purpleTint)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    // MARK: 日期 / 时间 / 备注

    private var dateRows: some View {
        VStack(spacing: 0) {
            HStack {
                Text("日期").font(.system(size: 13.5)).foregroundColor(Palette.subtle)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
            }
            .padding(.vertical, 4)

            Divider().background(Palette.hairlineSoft)

            HStack {
                Text("时间").font(.system(size: 13.5)).foregroundColor(Palette.subtle)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
            }
            .padding(.vertical, 4)
        }
        .cardStyle(padding: 14)
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("备注（可选）").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
            TextField("比如：夜里醒了两次", text: $note).font(.system(size: 15))
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.purpleTint)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    /// 辅食 / 补剂 / 自定义自己就是备注，不再多一个备注框
    private var showsExtraNote: Bool {
        !["solid", "supplement", "custom"].contains(entry.kind)
    }

    // MARK: 体温提示

    private var tempAccent: Color {
        if temperature >= 38.5 { return Palette.bad }
        if temperature >= 37.3 { return Palette.warn }
        return Palette.ok
    }

    private var tempHint: String {
        if temperature >= 38.5 {
            return "体温偏高，建议尽快就医；持续不退或精神差请直接去医院。"
        }
        if temperature >= 37.3 {
            return "体温略高，多喝水、少穿一点，隔 1 小时再测一次。"
        }
        return "体温正常，继续保持记录。"
    }

    // MARK: 初始值

    private func prepare() {
        if entry.kind == "sleep" { minutes = 30 }
        guard let child = store.current else { return }
        if let w = child.latestWeight, w > 0 { weight = min(60, max(0.5, w)) }
        if let h = child.latestHeight, h > 0 { height = min(160, max(30, h)) }
    }

    // MARK: 保存

    private func save() {
        if entry.kind == "weight" || entry.kind == "height" || entry.kind == "head" {
            saveGrowth()
        } else {
            saveFeed()
        }
        onClose()
    }

    private func saveFeed() {
        var log = FeedLog(date: date, kind: FeedLog.Kind(rawValue: entry.kind) ?? .custom)
        switch entry.kind {
        case "bottle", "pumping":
            log.ml = amount
        case "breast":
            log.minutes = Int(minutes.rounded())
            log.side = side
        case "sleep":
            log.minutes = Int(minutes.rounded())
        case "diaper":
            log.diaperKind = diaperKind
        case "solid":
            log.note = food.trimmed()
            if grams > 0 { log.value = grams }
        case "supplement":
            log.note = supplement.trimmed()
        case "temp":
            log.value = temperature
        default:
            log.kind = .custom
            let text = customText.trimmed()
            // 没填就退回入口名，和 Android 端保持一致
            log.note = text.isEmpty ? entry.title : text
        }
        if showsExtraNote, !note.trimmed().isEmpty {
            log.note = note.trimmed()
        }
        store.addFeed(log)
    }

    private func saveGrowth() {
        guard let child = store.current else { return }
        let existing = child.records.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        var record = existing ?? GrowthRecord(date: date)
        switch entry.kind {
        case "weight":
            record.weight = weight
        case "height":
            record.height = height
        default:
            record.headCirc = head
        }
        let extra = note.trimmed()
        if !extra.isEmpty {
            record.note = record.note.isEmpty ? extra : record.note + " · " + extra
        }
        if existing != nil {
            store.updateRecord(record)
        } else {
            store.addRecord(record)
        }
    }
}
