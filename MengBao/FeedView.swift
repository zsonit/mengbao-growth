import SwiftUI

// MARK: - 喂养

struct FeedView: View {
    @EnvironmentObject private var store: Store
    @State private var showAdd = false
    @State private var addKind: FeedLog.Kind = .sleep

    private var today: [FeedLog] {
        guard let child = store.current else { return [] }
        return child.feeds.filter { GrowthMath.isSameDay($0.date, Date()) }
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
        .navigationTitle("喂养")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    addKind = .sleep
                    showAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            if let child = store.current {
                FeedEditorView(child: child, kind: addKind)
            }
        }
    }

    private func content(_ child: Child) -> some View {
        let sleepMinutes = today.filter { $0.kind == .sleep }.reduce(0) { $0 + ($1.minutes ?? 0) }
        let breastCount = today.filter { $0.kind == .breast }.count
        let leftCount = today.filter { $0.kind == .breast && $0.side == "左" }.count
        let rightCount = today.filter { $0.kind == .breast && $0.side == "右" }.count
        let bottleML = today.filter { $0.kind == .bottle }.reduce(0.0) { $0 + ($1.ml ?? 0) }
        let diaperCount = today.filter { $0.kind == .diaper }.count

        return VStack(spacing: 0) {
            SectionHeader(title: "今日 · \(child.name)", trailing: GrowthMath.dateString(Date()))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
                feedCard(.sleep, value: "\(sleepMinutes)", unit: "分钟", hint: sleepMinutes > 0 ? "今日总计" : "点右上角 ＋ 记录")
                feedCard(.breast, value: "\(breastCount)", unit: "次", hint: "左 \(leftCount) · 右 \(rightCount)")
                feedCard(.bottle, value: "\(Int(bottleML))", unit: "ml", hint: bottleML > 0 ? "今日总计" : "点右上角 ＋ 记录")
                feedCard(.diaper, value: "\(diaperCount)", unit: "次", hint: diaperCount > 0 ? "今日总计" : "点右上角 ＋ 记录")
            }
            .padding(.horizontal, 16)

            SectionHeader(title: "最近 7 天")
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("睡眠时长").font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.ink)
                    Spacer()
                    Text("分钟").font(.system(size: 12)).foregroundColor(Palette.subtle)
                }
                barChart(values: last7(child) { $0.kind == .sleep ? Double($0.minutes ?? 0) : nil }, maxValue: 720)
            }
            .cardStyle()
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("奶量").font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.ink)
                    Spacer()
                    Text("ml").font(.system(size: 12)).foregroundColor(Palette.subtle)
                }
                barChart(values: last7(child) { $0.kind == .bottle ? ($0.ml ?? 0) : nil }, maxValue: 600)
            }
            .cardStyle()
            .padding(.horizontal, 16)
            .padding(.top, 11)

            SectionHeader(title: "今日明细")
            if today.isEmpty {
                EmptyHint(text: "今天还没有喂养记录")
            } else {
                VStack(spacing: 0) {
                    ForEach(today.sorted { $0.date > $1.date }) { log in
                        HStack(spacing: 10) {
                            Text(log.kind.icon).font(.system(size: 17))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(log.kind.title) · \(log.summary)").font(.system(size: 14)).foregroundColor(Palette.ink)
                                if !log.note.isEmpty {
                                    Text(log.note).font(.system(size: 12)).foregroundColor(Palette.subtle)
                                }
                            }
                            Spacer()
                            Text(log.date.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                            Button {
                                store.deleteFeed(log.id)
                            } label: {
                                Image(systemName: "trash").font(.system(size: 12)).foregroundColor(Palette.bad)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 9)
                    }
                }
                .cardStyle()
                .padding(.horizontal, 16)
            }

            if GrowthMath.ageMonths(from: child.birthDate) > 36 {
                HintBlock(text: "喂养模块主要面向 0–3 岁。孩子已经 \(GrowthMath.ageText(from: child.birthDate))，可以在「我的 → 功能开关」里隐藏这个模块。")
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
            Spacer(minLength: 28)
        }
    }

    private func feedCard(_ kind: FeedLog.Kind, value: String, unit: String, hint: String) -> some View {
        Button {
            addKind = kind
            showAdd = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Text(kind.icon).font(.system(size: 18))
                    Text(kind.title).font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.ink)
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Palette.purple)
                        .frame(width: 24, height: 24)
                        .background(Palette.purpleSoft)
                        .clipShape(Circle())
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value).font(.system(size: 25, weight: .bold)).foregroundColor(Palette.ink)
                    Text(unit).font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                }
                .padding(.top, 12)
                Text(hint).font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .padding(14)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func last7(_ child: Child, value: (FeedLog) -> Double?) -> [Double] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset -> Double in
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { return 0 }
            return child.feeds
                .filter { GrowthMath.isSameDay($0.date, day) }
                .compactMap { value($0) }
                .reduce(0, +)
        }
    }

    private func barChart(values: [Double], maxValue: Double) -> some View {
        let labels: [String] = (0..<7).reversed().map { offset in
            let cal = Calendar.current
            let day = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            return "\(cal.component(.day, from: day))日"
        }
        let peak = max(maxValue, values.max() ?? 1)
        return VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<values.count, id: \.self) { idx in
                    let ratio = peak > 0 ? values[idx] / peak : 0
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(values[idx] > 0 ? Palette.purple.opacity(0.55) : Palette.purpleTint)
                        .frame(height: max(3, CGFloat(ratio) * 46))
                        .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 50, alignment: .bottom)
            HStack(spacing: 5) {
                ForEach(0..<labels.count, id: \.self) { idx in
                    Text(labels[idx]).font(.system(size: 9)).foregroundColor(Palette.subtle)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - 喂养录入

struct FeedEditorView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let child: Child
    @State private var kind: FeedLog.Kind
    @State private var minutes = ""
    @State private var ml = ""
    @State private var side = "左"
    @State private var diaperKind = "小便"
    @State private var note = ""

    init(child: Child, kind: FeedLog.Kind) {
        self.child = child
        _kind = State(initialValue: kind)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(FeedLog.Kind.allCases) { k in
                            Button {
                                kind = k
                            } label: {
                                ChipLabel(text: k.title, selected: kind == k, icon: k.icon)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 10) {
                        if kind == .sleep || kind == .breast {
                            field(title: "时长", text: $minutes, unit: "分钟")
                        }
                        if kind == .bottle {
                            field(title: "奶量", text: $ml, unit: "ml")
                        }
                        if kind == .breast {
                            HStack(spacing: 8) {
                                ForEach(["左", "右", "双侧"], id: \.self) { s in
                                    Button { side = s } label: { ChipLabel(text: s, selected: side == s) }
                                        .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                        }
                        if kind == .diaper {
                            HStack(spacing: 8) {
                                ForEach(["小便", "大便", "混合"], id: \.self) { s in
                                    Button { diaperKind = s } label: { ChipLabel(text: s, selected: diaperKind == s) }
                                        .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("备注（可选）").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                            TextField("如：夜里醒了两次", text: $note).font(.system(size: 15))
                        }
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.purpleTint)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .cardStyle()

                    Button("保存记录") { save() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("记录喂养")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }

    private func field(title: String, text: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 11.5)).foregroundColor(Palette.subtle)
            HStack(spacing: 4) {
                TextField("0", text: text).keyboardType(.numberPad).font(.system(size: 16, weight: .semibold))
                Text(unit).font(.system(size: 12.5)).foregroundColor(Palette.subtle)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.purpleTint)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func save() {
        var log = FeedLog(date: Date(), kind: kind)
        switch kind {
        case .sleep:
            guard let m = Int(minutes), m > 0 else { return }
            log.minutes = m
        case .breast:
            log.side = side
            log.minutes = Int(minutes)
        case .bottle:
            guard let value = Double(ml), value > 0 else { return }
            log.ml = value
        case .diaper:
            log.diaperKind = diaperKind
        }
        log.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        store.addFeed(log)
        dismiss()
    }
}
