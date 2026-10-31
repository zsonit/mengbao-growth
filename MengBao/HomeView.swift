import SwiftUI

// MARK: - 首页

struct HomeView: View {
    @EnvironmentObject private var store: Store

    @State private var showRecord = false
    @State private var showKidEditor = false
    @State private var showSwitcher = false
    @State private var showSize = false
    @State private var showTodo = false
    @State private var showStage = false
    @State private var editingRecord: GrowthRecord? = nil

    var body: some View {
        ScrollView {
            if let child = store.current {
                content(for: child)
            } else {
                OnboardingView()
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("成长")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(store.state.children) { kid in
                        Button {
                            store.selectChild(kid.id)
                        } label: {
                            Text("\(kid.displayAvatar) \(kid.name)\(kid.id == store.state.currentID ? "  ✓" : "")")
                        }
                    }
                    if !store.state.children.isEmpty { Divider() }
                    Button { showKidEditor = true } label: { Label("编辑当前档案", systemImage: "pencil") }
                    Button { showSwitcher = true } label: { Label("管理宝宝", systemImage: "person.2") }
                } label: {
                    Text(store.current?.displayAvatar ?? "👶").font(.system(size: 20))
                }
            }
        }
        .sheet(isPresented: $showRecord) {
            if let child = store.current { RecordEditorView(child: child, record: nil) }
        }
        .sheet(item: $editingRecord) { record in
            if let child = store.current { RecordEditorView(child: child, record: record) }
        }
        .sheet(isPresented: $showKidEditor) { KidEditorView(child: store.current) }
        .sheet(isPresented: $showSwitcher) { KidsListView() }
        .sheet(isPresented: $showSize) {
            if let child = store.current { SizeEditorView(child: child) }
        }
        .sheet(isPresented: $showTodo) {
            if let child = store.current { TodoEditorView(child: child) }
        }
        .sheet(isPresented: $showStage) {
            if let child = store.current { StageSheet(child: child) }
        }
    }

    // MARK: 主体

    private func content(for child: Child) -> some View {
        VStack(spacing: 0) {
            hero(child)
            kpiRow(child)
            quickGrid
            stageCard(child)
            if !child.todos.isEmpty { todoCard(child) }
            shotCard(child)
            recentCard(child)
            HintBlock(text: Standards.disclaimer)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
        }
    }

    private func hero(_ child: Child) -> some View {
        let last = child.latestRecord
        let daysSince: Int? = last.map { Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day ?? 0 }
        let nextText: String = {
            guard let days = daysSince else { return "还没有记录，先量一次吧" }
            if days > 30 { return "已超过 \(days) 天，建议今天测量" }
            return "距上次 \(days) 天，建议 \(30 - days) 天内再测"
        }()
        let birthday = GrowthMath.daysToBirthday(child.birthDate)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(child.displayAvatar)
                    .font(.system(size: 24))
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.white.opacity(0.24)))
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(child.name).font(.system(size: 20, weight: .bold))
                    Text("\(GrowthMath.ageText(from: child.birthDate)) · \(birthday == 0 ? "今天生日 🎂" : "\(birthday) 天到生日")")
                        .font(.system(size: 12.5))
                        .opacity(0.95)
                }
                Spacer(minLength: 0)
            }

            HStack {
                Text("⏳ 下次测量").font(.system(size: 12.5))
                Spacer()
                Text(nextText).font(.system(size: 12.5, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.18)))
            .padding(.top, 14)

            HStack(spacing: 8) {
                Button { showRecord = true } label: {
                    Text("＋ 记一次身高体重")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.2)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.42), lineWidth: 1))
                }
                Button { showKidEditor = true } label: {
                    Text("档案")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.vertical, 9)
                        .padding(.horizontal, 18)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.2)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.42), lineWidth: 1))
                }
            }
            .foregroundColor(.white)
            .padding(.top, 12)
        }
        .foregroundColor(.white)
        .padding(18)
        .background(
            ZStack(alignment: .bottomTrailing) {
                Palette.heroGradient
                Circle().fill(Color.white.opacity(0.10)).frame(width: 170, height: 170).offset(x: 40, y: 60)
                Circle().fill(Color.white.opacity(0.08)).frame(width: 110, height: 110).offset(x: -110, y: -70)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func kpiRow(_ child: Child) -> some View {
        let last = child.latestRecord
        let evaluation = last.map { GrowthMath.evaluate(child: child, record: $0) }
        return HStack(spacing: 8) {
            kpi(value: last?.height.map { String(format: "%.1f", $0) } ?? "—",
                unit: "cm",
                title: "身高" + (evaluation?.heightPercentile.map { " " + GrowthMath.percentileLabel($0) } ?? ""))
            kpi(value: last?.weight.map { weightText($0) } ?? "—",
                unit: store.settings.weightUnit,
                title: "体重" + (evaluation?.weightPercentile.map { " " + GrowthMath.percentileLabel($0) } ?? ""))
            kpi(value: evaluation?.bmi.map { String(format: "%.1f", $0) } ?? "—", unit: "", title: "BMI")
            kpi(value: last?.footLength.map { String(format: "%.1f", $0) } ?? "—", unit: "cm", title: "脚长")
        }
        .padding(.horizontal, 16)
        .offset(y: -16)
        .padding(.bottom, -16)
    }

    private func kpi(value: String, unit: String, title: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value).font(.system(size: 17, weight: .bold))
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 10.5)).foregroundColor(Palette.subtle)
                }
            }
            Text(title).font(.system(size: 10.5)).foregroundColor(Palette.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.hairline, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }

    private var quickGrid: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "常用入口")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 12) {
                Button { showRecord = true } label: { quickItem("📝", "记录数据", 0) }
                    .buttonStyle(.plain)
                NavigationLink { GrowthDetailView() } label: { quickItem("📈", "生长曲线", 1) }
                    .buttonStyle(.plain)
                Button { showSize = true } label: { quickItem("👟", "鞋服尺码", 2) }
                    .buttonStyle(.plain)
                Button { showTodo = true } label: { quickItem("📋", "待办", 3) }
                    .buttonStyle(.plain)
                NavigationLink { HistoryView() } label: { quickItem("🕘", "历史记录", 4) }
                    .buttonStyle(.plain)
                NavigationLink { VaccineView() } label: { quickItem("💉", "接种计划", 5) }
                    .buttonStyle(.plain)
                NavigationLink { FeedView() } label: { quickItem("🍼", "喂养记录", 6) }
                    .buttonStyle(.plain)
                Button { showStage = true } label: { quickItem("⭐", "阶段重点", 7) }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
        }
    }

    private func quickItem(_ icon: String, _ title: String, _ index: Int) -> some View {
        let backgrounds: [Color] = [Palette.purpleTint, Palette.pinkBg, Palette.blueBg, Palette.okBg,
                                    Palette.warnBg, Palette.purpleSoft, Palette.purpleTint, Palette.pinkBg]
        return VStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 20))
                .frame(width: 46, height: 46)
                .background(backgrounds[index % backgrounds.count])
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Palette.hairline, lineWidth: 1))
            Text(title).font(.system(size: 12)).foregroundColor(Palette.ink2)
        }
    }

    private func stageCard(_ child: Child) -> some View {
        VStack(spacing: 0) {
            SectionHeader(title: "阶段重点", trailing: GrowthMath.ageText(from: child.birthDate))
            VStack(alignment: .leading, spacing: 8) {
                Text("这个阶段可以关注")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(Palette.purple)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Palette.purpleSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                ForEach(GrowthMath.milestones(for: child), id: \.self) { item in
                    HStack(alignment: .top, spacing: 7) {
                        Text("·").foregroundColor(Palette.subtle)
                        Text(item).font(.system(size: 13)).foregroundColor(Palette.ink2)
                    }
                }
                Button { showTodo = true } label: {
                    Text("加入待办清单")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Palette.purple)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Palette.purpleSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.top, 2)
            }
            .cardStyle()
            .padding(.horizontal, 16)
            .padding(.top, 0)
        }
        .padding(.top, 4)
    }

    private func todoCard(_ child: Child) -> some View {
        let sorted = child.todos.sorted { ($0.done ? 1 : 0) < ($1.done ? 1 : 0) }
        return VStack(spacing: 0) {
            SectionHeader(title: "待办", trailing: "新增", action: { showTodo = true })
            VStack(spacing: 0) {
                ForEach(sorted) { todo in
                    HStack(spacing: 10) {
                        Button { store.toggleTodo(todo.id) } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(todo.done ? Palette.ok : Palette.card)
                                    .frame(width: 21, height: 21)
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(todo.done ? Palette.ok : Palette.hairline, lineWidth: 1.6)
                                    .frame(width: 21, height: 21)
                                if todo.done {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Text(todo.title)
                            .font(.system(size: 13.5))
                            .foregroundColor(todo.done ? Palette.subtle : Palette.ink)
                            .strikethrough(todo.done, color: Palette.subtle)
                        Spacer(minLength: 6)
                        Button { store.deleteTodo(todo.id) } label: {
                            Image(systemName: "xmark").font(.system(size: 11)).foregroundColor(Palette.subtle)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 9)
                    if todo.id != sorted.last?.id {
                        Divider().background(Palette.hairlineSoft)
                    }
                }
            }
            .cardStyle(padding: 14)
            .padding(.horizontal, 16)
        }
        .padding(.top, 4)
    }

    private func shotCard(_ child: Child) -> some View {
        let schedule = GrowthMath.schedule(for: child)
        let done = schedule.filter { $0.status == .done }.count
        let due = schedule.filter { $0.status == .due }.count
        let total = GrowthMath.totalDoses
        let next = schedule.first { $0.status == .soon }
        return VStack(spacing: 0) {
            SectionHeader(title: "接种进度")
            NavigationLink { VaccineView() } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("已完成 \(done) / \(total) 剂").font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.ink)
                        Spacer()
                        Text("\(Int(Double(done) / Double(max(total, 1)) * 100))%")
                            .font(.system(size: 12)).foregroundColor(Palette.subtle)
                    }
                    ProgressBar(value: Double(done) / Double(max(total, 1)))
                    Text(due > 0 ? "⚠️ \(due) 剂已到期未种"
                         : (next.map { "下一针：\($0.ageLabel) · \($0.vaccine.name)" } ?? "全部按计划完成"))
                        .font(.system(size: 12))
                        .foregroundColor(due > 0 ? Palette.bad : Palette.subtle)
                }
                .cardStyle(padding: 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }

    private func recentCard(_ child: Child) -> some View {
        let records = Array(child.sortedRecords.reversed().prefix(2))
        return VStack(spacing: 0) {
            SectionHeader(title: "最近记录", trailing: "全部 ›")
            if records.isEmpty {
                EmptyHint(text: "还没有记录，点「记一次身高体重」开始")
            } else {
                ForEach(records) { record in
                    Button { editingRecord = record } label: {
                        RecordMiniCard(child: child, record: record, weightUnit: store.settings.weightUnit)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
            }
        }
    }

    private func weightText(_ kg: Double) -> String {
        store.settings.weightUnit == "斤" ? String(format: "%.1f", kg * 2) : String(format: "%.1f", kg)
    }
}

// MARK: - 记录小卡

struct RecordMiniCard: View {
    let child: Child
    let record: GrowthRecord
    var weightUnit: String = "kg"

    var body: some View {
        let evaluation = GrowthMath.evaluate(child: child, record: record)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(GrowthMath.dateString(record.date))
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.ink2)
                Text(GrowthMath.ageText(from: child.birthDate, to: record.date))
                    .font(.system(size: 12)).foregroundColor(Palette.subtle)
                Spacer()
                if let p = evaluation.heightPercentile {
                    TagView(text: GrowthMath.percentileLabel(p),
                            tone: evaluation.heightLevel?.tone == .bad ? .bad : (evaluation.heightLevel?.tone == .warn ? .warn : .ok))
                }
            }
            HStack(spacing: 8) {
                mini(value: record.height.map { String(format: "%.1f", $0) } ?? "—", unit: "身高cm")
                mini(value: record.weight.map { String(format: "%.1f", weightUnit == "斤" ? $0 * 2 : $0) } ?? "—", unit: "体重\(weightUnit)")
                mini(value: evaluation.bmi.map { String(format: "%.1f", $0) } ?? "—", unit: "BMI")
                mini(value: record.footLength.map { String(format: "%.0f", $0) } ?? "—", unit: "脚长cm")
            }
            if !record.note.isEmpty {
                Text(record.note).font(.system(size: 12)).foregroundColor(Palette.subtle)
            }
        }
        .cardStyle(padding: 14)
    }

    private func mini(value: String, unit: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(Palette.ink)
            Text(unit).font(.system(size: 10.5)).foregroundColor(Palette.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Palette.purpleTint)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - 首次使用引导

struct OnboardingView: View {
    @EnvironmentObject private var store: Store
    @State private var showEditor = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text("🍼").font(.system(size: 24))
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white.opacity(0.24)))
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("欢迎使用萌宝成长").font(.system(size: 19, weight: .bold))
                        Text("记录身高体重 · 看懂生长曲线 · 管好疫苗本").font(.system(size: 12.5)).opacity(0.95)
                    }
                    Spacer(minLength: 0)
                }
                Button { showEditor = true } label: {
                    Text("＋ 添加宝宝档案")
                        .font(.system(size: 13.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.22)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.45), lineWidth: 1))
                }
            }
            .foregroundColor(.white)
            .padding(18)
            .background(Palette.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(16)

            VStack(spacing: 0) {
                SectionHeader(title: "能做什么")
                VStack(spacing: 0) {
                    KVRow(key: "📈 生长曲线", value: "身高 / 体重 / BMI 百分位")
                    KVRow(key: "💉 接种计划", value: "广东免疫规划 \(GrowthMath.totalDoses) 剂")
                    KVRow(key: "🍼 喂养记录", value: "睡眠 · 奶量 · 尿布")
                    KVRow(key: "👟 鞋服尺码", value: "脚长换算 + 身高对应码")
                    KVRow(key: "🔒 数据归属", value: "只存本机，可导出备份")
                }
                .cardStyle()
                .padding(.horizontal, 16)
            }

            VStack(spacing: 0) {
                SectionHeader(title: "先看看效果")
                VStack(alignment: .leading, spacing: 12) {
                    Text("载入一份示例数据（11 岁姐姐 + 8 个月弟弟），体验完整流程后可以随时删除。")
                        .font(.system(size: 13)).foregroundColor(Palette.subtle).lineSpacing(3)
                    Button("载入示例数据") { store.loadDemo() }
                        .buttonStyle(PrimaryButtonStyle(filled: false))
                }
                .cardStyle()
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showEditor) { KidEditorView(child: nil) }
    }
}
