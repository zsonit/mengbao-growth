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
    @State private var amount: Double = 150          // 瓶喂 / 吸奶 / 储奶 ml
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
    @State private var milkSource = "奶粉"            // 瓶喂：奶粉 / 人奶
    @State private var storageKind = "冷藏"           // 储奶：冷藏 / 冷冻
    @State private var medicineName = ""             // 喂药：药名
    @State private var dose: Double = 5              // 喂药：剂量 ml
    @State private var medicineReason = ""           // 喂药：原因
    @State private var notebookTag = ""              // 记事本：异常标签
    @State private var notebookText = ""             // 记事本：正文
    @State private var doseRemindOn = false          // 补剂/喂药：每天提醒开关
    @State private var doseTimes: [Date] = []        // 补剂/喂药：每天提醒时间点
    @State private var detent: PresentationDetent = .fraction(0.8)

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
                    if entry.kind == "medicine" || entry.kind == "supplement" {
                        doseReminderCard
                    }
                    dateRows
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
        // 默认 80% 高度：比半屏高，备注一眼能看到；内容多的类型可以再往上拖到全高
        .presentationDetents([.fraction(0.8), .large], selection: $detent)
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
        case "bottle":
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("这一顿喝的是")
                textChips(EntryPresets.milkSources, current: milkSource) { milkSource = $0 }
                Divider().background(Palette.hairlineSoft)
                bigValue(String(format: "%.0f", amount), unit: "ml")
                RulerPicker(value: $amount, range: 0...300, step: 5, format: "%.0f", unit: "ml")
                numberChips(EntryPresets.milkAmounts, format: "%.0f", unit: "ml", current: amount) { amount = $0 }
            }
            .cardStyle()

        case "pumping":
            VStack(spacing: 12) {
                bigValue(String(format: "%.0f", amount), unit: "ml")
                RulerPicker(value: $amount, range: 0...300, step: 5, format: "%.0f", unit: "ml")
                numberChips(EntryPresets.milkAmounts, format: "%.0f", unit: "ml", current: amount) { amount = $0 }
            }
            .cardStyle()

        case "storage":
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("存放方式")
                textChips(EntryPresets.storageKinds, current: storageKind) { storageKind = $0 }
                Divider().background(Palette.hairlineSoft)
                bigValue(String(format: "%.0f", amount), unit: "ml")
                RulerPicker(value: $amount, range: 0...300, step: 5, format: "%.0f", unit: "ml")
                numberChips(EntryPresets.milkAmounts, format: "%.0f", unit: "ml", current: amount) { amount = $0 }
                Text(storageHint)
                    .font(.system(size: 12))
                    .foregroundColor(Palette.subtle)
            }
            .cardStyle()

        case "medicine":
            VStack(alignment: .leading, spacing: 12) {
                simpleField(title: "吃了什么药", placeholder: "例如 美林 布洛芬混悬液", text: $medicineName)
                textChips(EntryPresets.medicineNames, current: medicineName) { medicineName = $0 }
                Divider().background(Palette.hairlineSoft)
                sectionLabel("吃了多少")
                bigValue(String(format: "%.1f", dose), unit: "ml")
                RulerPicker(value: $dose, range: 0...20, step: 0.5, format: "%.1f", unit: "ml")
                Divider().background(Palette.hairlineSoft)
                sectionLabel("为什么吃（可不选）")
                textChips(EntryPresets.medicineReasons, current: medicineReason) { reason in
                    medicineReason = (medicineReason == reason) ? "" : reason
                }
            }
            .cardStyle()

        case "notebook":
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("异常情况（点一下加进记录）")
                textChips(EntryPresets.notebookTags, current: notebookTag) { tag in
                    notebookTag = (notebookTag == tag) ? "" : tag
                }
                Divider().background(Palette.hairlineSoft)
                multilineField(placeholder: "详细记一笔：什么时候、什么样、有没有处理…", text: $notebookText)
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

    // MARK: 补剂 / 喂药：每天提醒

    /// 打开开关后可以加任意多个时间点，每天到点由本机通知提醒（不联网）
    private var doseReminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.kind == "medicine" ? "每天提醒我吃药" : "每天提醒我吃补剂")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    Text("打开后到点本机提醒，可以加多个时间")
                        .font(.system(size: 11.5))
                        .foregroundColor(Palette.subtle)
                }
                Spacer()
                Toggle("", isOn: $doseRemindOn)
                    .labelsHidden()
                    .tint(Palette.purple)
                    .onChange(of: doseRemindOn) { on in
                        if on && doseTimes.isEmpty {
                            doseTimes = [Self.time(from: "09:00") ?? Date()]
                        }
                    }
            }

            if doseRemindOn {
                Divider().background(Palette.hairlineSoft)
                ForEach(Array(doseTimes.indices), id: \.self) { i in
                    HStack(spacing: 10) {
                        DatePicker("", selection: Binding(
                            get: { doseTimes.indices.contains(i) ? doseTimes[i] : Date() },
                            set: { if doseTimes.indices.contains(i) { doseTimes[i] = $0 } }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_CN"))

                        Spacer()

                        Button {
                            if doseTimes.indices.contains(i) { doseTimes.remove(at: i) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Palette.subtle.opacity(0.6))
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }

                Button {
                    let last = doseTimes.last ?? Self.time(from: "09:00") ?? Date()
                    doseTimes.append(last.addingTimeInterval(6 * 3600))
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 14))
                        Text("添加提醒时间").font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundColor(Palette.purple)
                }
                .buttonStyle(SoftPressStyle())

                Text("提醒会每天重复，直到你把这个开关关掉。")
                    .font(.system(size: 11.5))
                    .foregroundColor(Palette.subtle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private static func time(from text: String) -> Date? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        var comps = DateComponents()
        comps.hour = h
        comps.minute = m
        return Calendar.current.date(from: comps)
    }

    private static func text(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundColor(Palette.subtle)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 记事本用的多行输入：自带配色与占位提示，避免 TextEditor 默认白底
    private func multilineField(placeholder: String, text: Binding<String>) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14.5))
                    .foregroundColor(Palette.subtle.opacity(0.65))
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }
            TextEditor(text: text)
                .font(.system(size: 15))
                .frame(minHeight: 118)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.purpleTint)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var storageHint: String {
        storageKind == "冷冻"
            ? "冷冻一般可存 3 个月左右，放冰箱最里层，写明日期先存先用。"
            : "冷藏一般 24 小时内喝完，放冰箱最里层，别放门上。"
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

            // 备注跟日期时间放同一张卡里：70% 高度下也能直接看到「备注（可选）」
            if showsExtraNote {
                Divider().background(Palette.hairlineSoft)
                noteField.padding(.top, 8)
            }
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

    /// 辅食 / 补剂 / 喂药 / 记事本 / 自定义自己就是备注，不再多一个备注框
    private var showsExtraNote: Bool {
        !["solid", "supplement", "medicine", "notebook", "custom"].contains(entry.kind)
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
        // 补剂 / 喂药：把已经设过的每日提醒读回来，下次打开还能改
        if entry.kind == "medicine" || entry.kind == "supplement" {
            let s = store.settings
            let isMed = entry.kind == "medicine"
            doseRemindOn = isMed ? s.medReminderOn : s.suppReminderOn
            let saved = isMed ? s.medReminderTimes : s.suppReminderTimes
            doseTimes = saved.compactMap { Self.time(from: $0) }
            if doseRemindOn && doseTimes.isEmpty {
                doseTimes = [Self.time(from: "09:00") ?? Date()]
            }
        }
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
        case "bottle":
            log.ml = amount
            log.tag = milkSource
        case "pumping":
            log.ml = amount
        case "storage":
            log.ml = amount
            log.tag = storageKind
        case "medicine":
            let name = medicineName.trimmed()
            log.note = name.isEmpty ? "喂药" : name
            log.value = dose
            log.tag = medicineReason.isEmpty ? nil : medicineReason
        case "notebook":
            let body = notebookText.trimmed()
            log.note = body.isEmpty ? (notebookTag.isEmpty ? "记事本" : notebookTag) : body
            log.tag = notebookTag.isEmpty ? nil : notebookTag
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

        // 补剂 / 喂药：顺手保存「每天提醒」（去重 + 按时间排序，没有时间点就不开提醒）
        let times = Array(Set(doseTimes.map { Self.text(from: $0) })).sorted()
        if entry.kind == "medicine" {
            store.setMedReminder(on: doseRemindOn && !times.isEmpty, times: times)
        } else if entry.kind == "supplement" {
            store.setSuppReminder(on: doseRemindOn && !times.isEmpty, times: times)
        }
        if doseRemindOn && !times.isEmpty {
            // 第一次打开提醒时补问一次通知权限，避免「开了却不响」
            NotificationManager.shared.ensureAuthorized()
        }
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
