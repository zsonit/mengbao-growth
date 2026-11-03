import SwiftUI
import UIKit

// MARK: - 首页

struct HomeView: View {
    @EnvironmentObject private var store: Store

    @State private var showRecord = false
    @State private var showKidEditor = false
    @State private var showSwitcher = false
    @State private var showSize = false
    @State private var showTeeth = false
    @State private var showTodo = false
    @State private var showStage = false
    @State private var activeEntry: QuickEntry? = nil

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
                    AvatarView(child: store.current, size: 40, fontSize: 20)
                }
            }
        }
        .sheet(item: $activeEntry) { entry in
            EntrySheet(entry: entry) { activeEntry = nil }
        }
        .sheet(isPresented: $showRecord) {
            if let child = store.current { RecordEditorView(child: child, record: nil) }
        }
        .sheet(isPresented: $showKidEditor) { KidEditorView(child: store.current) }
        .sheet(isPresented: $showSwitcher) { KidsListView() }
        .sheet(isPresented: $showSize) {
            if let child = store.current { SizeEditorView(child: child) }
        }
        .sheet(isPresented: $showTeeth) {
            if let child = store.current { ToothChartView(child: child) }
        }
        .sheet(isPresented: $showTodo) {
            if let child = store.current { TodoEditorView(child: child) }
        }
        .sheet(isPresented: $showStage) {
            if let child = store.current { StageSheet(child: child) }
        }
        .overlay(alignment: .bottom) {
            if store.current != nil {
                HoldToTalkButton { page in
                    openAIPage(page)
                }
                // 悬在玻璃栏正上方留 6pt 缝隙（栏顶 = 指示条34 + 栏2 + 栏高54 = 90，
                // padding 96 → 按钮底边在栏顶上方 6pt）。不压住标签栏和卡片内容，
                // 又贴着屏幕底部好按。按住说话时玻璃栏自动收起（RootView）。
                .padding(.bottom, 96)
            }
        }
    }

    // MARK: 主体

    private func content(for child: Child) -> some View {
        VStack(spacing: 0) {
            // 各区块错开几十毫秒淡入上浮，进页面时像玻璃一片片落定，而不是「唰」地全出现
            header(child).softAppear(delay: 0)
            aiCard(child).softAppear(delay: 0.04)
            if store.settings.showFeed { todaySection(child).softAppear(delay: 0.08) }
            if store.settings.showFeed {
                quickEntryRow.softAppear(delay: 0.11)
            }
            commonTools.softAppear(delay: 0.14)
            recentCard(child).softAppear(delay: 0.17)
            extras(child).softAppear(delay: 0.20)
            HintBlock(text: Standards.disclaimer)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 176)
        }
    }

    /// 阶段重点 / 待办 / 接种进度（样式沿用旧版）
    private func extras(_ child: Child) -> some View {
        VStack(spacing: 0) {
            stageCard(child)
            if !child.todos.isEmpty { todoCard(child) }
            shotCard(child)
        }
    }

    // MARK: 1. 宝宝头部

    private func header(_ child: Child) -> some View {
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: child.birthDate),
                                      to: cal.startOfDay(for: Date())).day ?? 0
        let dayNumber = max(0, days)
        return HStack(spacing: 12) {
            AvatarView(child: child, size: 50, fontSize: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(child.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Palette.ink)
                Text("第 \(dayNumber) 天 · \(GrowthMath.ageText(from: child.birthDate))")
                    .font(.system(size: 12.5))
                    .foregroundColor(Palette.subtle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: 2. AI 分析卡

    private func aiCard(_ child: Child) -> some View {
        let card = AISuggest.card(for: child, settings: store.settings)
        return VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(card.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Text(card.body)
                        .font(.system(size: 13))
                        .foregroundColor(Palette.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    aiAction(card)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Text(card.tone.emoji)
                    .font(.system(size: 26))
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(LinearGradient(colors: circleColors(card.tone),
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: cardColors(card.tone),
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            NavigationLink { VoiceAssistantView() } label: {
                HStack(spacing: 7) {
                    Text("🎙️").font(.system(size: 14))
                    Text("说一句就记下").font(.system(size: 13, weight: .semibold)).foregroundColor(Palette.ink)
                    Text("「十点喝了 120 的奶」").font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(Palette.purple)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Palette.purpleTint)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .padding(.horizontal, 16)
            }
            .buttonStyle(SoftPressStyle())

            Text("* AI 分析仅供参考，不能替代医疗建议")
                .font(.system(size: 10.5))
                .foregroundColor(Palette.subtle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
        }
    }

    @ViewBuilder
    private func aiAction(_ card: AISuggestion) -> some View {
        switch card.action {
        case .entry(let id):
            Button { activeEntry = quickEntry(for: id) } label: { actionChip(card.actionTitle) }
                .buttonStyle(SoftPressStyle())
        case .growth:
            NavigationLink { GrowthDetailView() } label: { actionChip(card.actionTitle) }
                .buttonStyle(SoftPressStyle())
        case .vaccine:
            NavigationLink { VaccineView() } label: { actionChip(card.actionTitle) }
                .buttonStyle(SoftPressStyle())
        case AISuggestion.Action.none:
            EmptyView()
        }
    }

    private func actionChip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundColor(Palette.purple)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Palette.purpleSoft)
            .clipShape(Capsule())
    }

    private func cardColors(_ tone: AISuggestion.Tone) -> [Color] {
        switch tone {
        case .info: return [Palette.purpleTint, Palette.card]
        case .ok: return [Palette.okBg, Palette.card]
        case .warn: return [Palette.warnBg, Palette.card]
        case .bad: return [Palette.badBg, Palette.card]
        }
    }

    private func circleColors(_ tone: AISuggestion.Tone) -> [Color] {
        switch tone {
        case .info: return [Color(hex: 0xC9B6FF), Color(hex: 0xA97BFF)]
        case .ok: return [Color(hex: 0x9EE7C6), Color(hex: 0x4DBE91)]
        case .warn: return [Color(hex: 0xFFD08A), Color(hex: 0xFF9F45)]
        case .bad: return [Color(hex: 0xFFB0A0), Color(hex: 0xF2715C)]
        }
    }

    // MARK: 3. 今日记录

    private func todaySection(_ child: Child) -> some View {
        let feeds = child.feeds.filter { GrowthMath.isSameDay($0.date, Date()) }
        let ml = feeds.filter { $0.kind == .bottle }.reduce(0.0) { $0 + ($1.ml ?? 0) }
        let minutes = feeds.filter { $0.kind == .sleep }.reduce(0) { $0 + ($1.minutes ?? 0) }
        let diapers = feeds.filter { $0.kind == .diaper }.count
        return VStack(spacing: 0) {
            SectionHeader(title: "今日记录")
            HStack(spacing: 10) {
                statCard(emoji: "🍼", value: "\(Int(ml))ml", title: "瓶喂",
                         bg: Palette.pinkBg, accent: Color(hex: 0xFF8FB1), kind: "bottle")
                statCard(emoji: "😴", value: sleepText(minutes), title: "睡眠",
                         bg: Palette.blueBg, accent: Color(hex: 0x5AA9FF), kind: "sleep")
                statCard(emoji: "🧷", value: "\(diapers)次", title: "换尿布",
                         bg: Palette.okBg, accent: Palette.ok, kind: "diaper")
            }
            .padding(.horizontal, 16)
        }
    }

    private func statCard(emoji: String, value: String, title: String,
                          bg: Color, accent: Color, kind: String) -> some View {
        Button {
            activeEntry = quickEntry(for: kind)
        } label: {
            VStack(spacing: 5) {
                Text(emoji).font(.system(size: 22))
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(Palette.subtle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(accent))
                    .padding(7)
            }
        }
        .buttonStyle(SoftPressStyle())
    }

    /// 分钟数 → 45m / 1h / 1h20m（与 Android 端一致）
    private func sleepText(_ minutes: Int) -> String {
        if minutes <= 0 { return "0m" }
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }

    // MARK: 4. 快捷入口横滑

    private var quickEntryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.homeQuickEntries) { entry in
                    Button { activeEntry = entry } label: {
                        HStack(spacing: 5) {
                            Text(entry.icon).font(.system(size: 13))
                            Text(entry.title)
                                .font(.system(size: 13))
                                .foregroundColor(Palette.ink2)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Palette.card)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Palette.hairline, lineWidth: 1))
                    }
                    .buttonStyle(SoftPressStyle())
                }

                NavigationLink { QuickEntryManagerView() } label: {
                    HStack(spacing: 5) {
                        Text("⚙️").font(.system(size: 12))
                        Text("配置")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Palette.purple)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Palette.purpleTint)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Palette.purple.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(SoftPressStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: 5. 常用工具

    private var commonTools: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "常用工具")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 12) {
                NavigationLink { GrowthDetailView() } label: {
                    toolItem("📈", "生长曲线", Palette.purpleTint)
                }
                .buttonStyle(SoftPressStyle())

                if store.settings.showFeed && store.settings.showTrends {
                    NavigationLink { TrendsView() } label: {
                        toolItem("📊", "成长趋势", Palette.blueBg)
                    }
                    .buttonStyle(SoftPressStyle())
                }

                NavigationLink { VaccineView() } label: {
                    toolItem("💉", "接种计划", Palette.pinkBg)
                }
                .buttonStyle(SoftPressStyle())

                if store.settings.showFeed {
                    NavigationLink { FeedView() } label: {
                        toolItem("🍼", "喂养记录", Palette.blueBg)
                    }
                    .buttonStyle(SoftPressStyle())
                }

                NavigationLink { HistoryView() } label: {
                    toolItem("🕘", "历史记录", Palette.okBg)
                }
                .buttonStyle(SoftPressStyle())

                if store.settings.showSize {
                    Button { showSize = true } label: {
                        toolItem("👟", "鞋服尺码", Palette.warnBg)
                    }
                    .buttonStyle(SoftPressStyle())
                }

                Button { showTeeth = true } label: {
                    toolItem("🦷", "换牙档案", Palette.pinkBg)
                }
                .buttonStyle(SoftPressStyle())

                Button { showTodo = true } label: {
                    toolItem("📋", "待办", Palette.purpleSoft)
                }
                .buttonStyle(SoftPressStyle())

                Button { showStage = true } label: {
                    toolItem("⭐", "阶段重点", Palette.blueBg)
                }
                .buttonStyle(SoftPressStyle())

                Button { showRecord = true } label: {
                    toolItem("📏", "记身高体重", Palette.pinkBg)
                }
                .buttonStyle(SoftPressStyle())
            }
            .padding(.horizontal, 12)
        }
    }

    private func toolItem(_ icon: String, _ title: String, _ background: Color) -> some View {
        VStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 20))
                .frame(width: 46, height: 46)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Palette.hairline, lineWidth: 1))
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Palette.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: 6. 近 24 小时活动

    private func recentCard(_ child: Child) -> some View {
        let cutoff = Date().addingTimeInterval(-24.0 * 3600)
        let now = Date()
        var logs = child.feeds.filter { $0.date >= cutoff && $0.date <= now }
        if !store.settings.showFeed {
            logs = logs.filter { $0.kind == .temp || $0.kind == .custom }
        }
        let items = Array(logs.sorted { $0.date > $1.date }.prefix(6))

        return VStack(spacing: 0) {
            HStack {
                Text("近 24 小时活动")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.subtle)
                Spacer()
                NavigationLink { HistoryView() } label: {
                    Text("历史 ›")
                        .font(.system(size: 12))
                        .foregroundColor(Palette.purple)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 8)

            if items.isEmpty {
                EmptyHint(text: "暂无记录")
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { log in
                        HStack(spacing: 10) {
                            Text(log.kind.icon)
                                .font(.system(size: 15))
                                .frame(width: 32, height: 32)
                                .background(Palette.purpleTint)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.kind.title)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundColor(Palette.ink)
                                Text(log.summary)
                                    .font(.system(size: 12))
                                    .foregroundColor(Palette.subtle)
                            }
                            Spacer(minLength: 6)
                            Text(timeText(log.date))
                                .font(.system(size: 12))
                                .foregroundColor(Palette.subtle)
                        }
                        .padding(.vertical, 8)
                        if log.id != items.last?.id {
                            Divider().background(Palette.hairlineSoft)
                        }
                    }
                }
                .cardStyle(padding: 14)
                .padding(.horizontal, 16)
            }
        }
    }

    private func timeText(_ date: Date) -> String {
        HomeView.hourMinute.string(from: date)
    }

    private static let hourMinute: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    // MARK: 7. 阶段 / 待办 / 接种

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
                        .buttonStyle(SoftPressStyle())
                        Text(todo.title)
                            .font(.system(size: 13.5))
                            .foregroundColor(todo.done ? Palette.subtle : Palette.ink)
                            .strikethrough(todo.done, color: Palette.subtle)
                        if let due = todo.due, !todo.done {
                            Text(todoDueShort(due))
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(todoOverdue(due) ? Palette.bad : Palette.purple)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(todoOverdue(due) ? Palette.badBg : Palette.purpleTint)
                                .clipShape(Capsule())
                        }
                        Spacer(minLength: 6)
                        // 本机提醒开关：🔔 会在到期时响，🔕 本机静音（不影响另一台手机，待办内容照样同步）
                        if todo.due != nil && !todo.done {
                            let muted = store.settings.mutedTodoReminders.contains(todo.id.uuidString)
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                store.toggleTodoMute(todo.id)
                            } label: {
                                Image(systemName: muted ? "bell.slash" : "bell.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(muted ? Palette.subtle : Palette.purple)
                                    .frame(width: 26, height: 26)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                        Button { store.deleteTodo(todo.id) } label: {
                            Image(systemName: "xmark").font(.system(size: 11)).foregroundColor(Palette.subtle)
                        }
                        .buttonStyle(SoftPressStyle())
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

    private func todoDueShort(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if days == 0 { return "今天" }
        if days == 1 { return "明天" }
        if days == 2 { return "后天" }
        if days < 0 { return "已过期" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    private func todoOverdue(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: Date())
    }

    private func shotCard(_ child: Child) -> some View {
        let schedule = GrowthMath.schedule(for: child)
        let done = schedule.filter { $0.status == .done }.count
        let due = schedule.filter { $0.status == .due }.count
        let total = schedule.count
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
            .buttonStyle(SoftPressStyle())
        }
    }

    // MARK: 8. AI 按住说话 → 结果面板里的跳页

    private func openAIPage(_ page: String) {
        switch page {
        case "todo": showTodo = true
        case "size": showSize = true
        case "teeth": showTeeth = true
        case "growth", "stage": showStage = true
        default: break
        }
    }

    // MARK: 辅助

    /// 按 kind 找一个可用的快捷入口（找不到就现造一个，保证弹层总能打开）
    private func quickEntry(for kind: String) -> QuickEntry {
        if let hit = store.quickEntries.first(where: { $0.kind == kind }) { return hit }
        if let k = FeedLog.Kind(rawValue: kind) {
            return QuickEntry(id: kind, kind: kind, title: k.title, icon: k.icon)
        }
        switch kind {
        case "weight": return QuickEntry(id: "weight", kind: "weight", title: "体重", icon: "⚖️")
        case "height": return QuickEntry(id: "height", kind: "height", title: "身高", icon: "📏")
        case "head": return QuickEntry(id: "head", kind: "head", title: "头围", icon: "🧢")
        default: return QuickEntry(id: "custom", kind: "custom", title: "记录", icon: "📝")
        }
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
                    KVRow(key: "🦷 换牙档案", value: "乳牙脱落 + 换牙时间表 + 龋齿记录")
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
