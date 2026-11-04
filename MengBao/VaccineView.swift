import SwiftUI

// MARK: - 接种计划

struct VaccineView: View {
    @EnvironmentObject private var store: Store

    private let ageFilters: [(String, ClosedRange<Int>?)] = [
        ("全部", nil), ("0 岁", 0...11), ("1 岁", 12...17), ("2 岁", 18...35),
        ("3 岁", 36...47), ("4 岁", 48...71), ("6 岁", 72...400)
    ]

    @State private var ageFilter = "全部"
    @State private var filter = "全部"
    @State private var showOptional = false

    private let statusFilters = ["全部", "待接种", "已完成"]

    var body: some View {
        ScrollView {
            if let child = store.current {
                content(child)
            } else {
                EmptyHint(text: "先添加宝宝档案，自动生成接种计划")
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("接种计划")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showOptional) {
            OptionalVaccineSheet(selected: store.current?.optVaccines ?? []) { ids in
                store.setOptVaccines(ids)
            }
        }
    }

    private func content(_ child: Child) -> some View {
        let schedule = GrowthMath.schedule(for: child)
        let done = schedule.filter { $0.status == .done }.count
        let due = schedule.filter { $0.status == .due }.count
        let total = schedule.count
        let percent = Int(Double(done) / Double(max(total, 1)) * 100)
        let next = schedule.first { $0.status == .soon }
        let range = ageFilters.first { $0.0 == ageFilter }?.1
        var visible = range == nil ? schedule : schedule.filter { range!.contains($0.months) }
        if filter == "待接种" {
            visible = visible.filter { $0.status != .done }
        } else if filter == "已完成" {
            visible = visible.filter { $0.status == .done }
        }

        return VStack(spacing: 0) {
            // 顶部日程卡
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    AvatarView(child: child, size: 50, fontSize: 24, bg: Color.white.opacity(0.24))
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(child.name) 的接种日程").font(.system(size: 19, weight: .bold))
                        Text("已接种 \(done)/\(total) 剂 · 完成 \(percent)%")
                            .font(.system(size: 12.5)).opacity(0.95)
                    }
                    Spacer(minLength: 0)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.28))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * CGFloat(min(1.0, Double(done) / Double(max(total, 1)))))
                    }
                }
                .frame(height: 8)
                .padding(.top, 14)

                Text("依据国家免疫规划疫苗儿童免疫程序表（\(Standards.scheduleYear) 年版，每年自动更新）")
                    .font(.system(size: 11))
                    .opacity(0.92)
                    .padding(.top, 8)

                NavigationLink { YamiaoView() } label: {
                    Text("📍 粤苗官方 · 定位查接种门诊 →")
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.2)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.45), lineWidth: 1))
                }
                .padding(.top, 10)
            }
            .foregroundColor(.white)
            .padding(18)
            .background(
                ZStack(alignment: .bottomTrailing) {
                    Palette.warmGradient
                    Circle().fill(Color.white.opacity(0.14)).frame(width: 160, height: 160).offset(x: 40, y: 56)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            VStack(spacing: 0) {
                KVRow(key: "已完成", value: "\(done) / \(total) 剂", valueColor: Palette.ok)
                Divider().background(Palette.hairlineSoft)
                KVRow(key: "已到期未种", value: "\(due) 剂", valueColor: due > 0 ? Palette.bad : Palette.subtle)
                Divider().background(Palette.hairlineSoft)
                KVRow(key: "下一针", value: next.map { "\($0.ageLabel) · \($0.vaccine.name)" } ?? "全部按计划完成")
                Divider().background(Palette.hairlineSoft)
                KVRow(key: "适用标准", value: "国家免疫规划 \(Standards.scheduleYear) 版")
            }
            .cardStyle(padding: 14)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            optionalEntry

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(statusFilters, id: \.self) { item in
                        Button { withAnimation(Anim.tap) { filter = item } } label: {
                            ChipLabel(text: item, selected: filter == item)
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                    Divider().frame(height: 18).padding(.horizontal, 2)
                    ForEach(ageFilters, id: \.0) { item in
                        Button { withAnimation(Anim.tap) { ageFilter = item.0 } } label: {
                            ChipLabel(text: item.0, selected: ageFilter == item.0)
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 14)

            HintBlock(text: "点击卡片可切换「已接种 / 未接种」。同一天可同时接种多种疫苗（不同部位），接种后需留观 30 分钟。补种原则：未完成剂次按程序补齐，不需重新开始。")
                .padding(.horizontal, 16)
                .padding(.top, 10)

            ForEach(visible) { dose in
                Button {
                    withAnimation(Anim.pop) { store.toggleShot(key: dose.key) }
                } label: {
                    DoseCard(dose: dose)
                }
                .buttonStyle(SoftPressStyle())
                .padding(.horizontal, 16)
                .padding(.top, 9)
            }
            .transition(.opacity)
            .animation(Anim.soft, value: visible.map(\.key))

            SectionHeader(title: "非免疫规划疫苗（自费 · 自愿）")
            VStack(spacing: 0) {
                ForEach(Standards.optionalVaccines, id: \.0) { item in
                    KVRow(key: "💉 \(item.0)", value: item.1)
                    if item.0 != Standards.optionalVaccines.last?.0 {
                        Divider().background(Palette.hairlineSoft)
                    }
                }
                Text("优先考虑水痘、EV71 手足口、Hib、13 价肺炎。与免疫规划疫苗时间冲突时，优先保证免疫规划疫苗。是否接种请与接种医生沟通。")
                    .font(.system(size: 12)).foregroundColor(Palette.subtle).lineSpacing(3).padding(.top, 10)
            }
            .cardStyle()
            .padding(.horizontal, 16)

            NavigationLink { ClinicListView() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Palette.purple)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("常见接种门诊速查")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Palette.ink)
                        Text("离线名录，没网或想先看地址电话时用")
                            .font(.system(size: 11))
                            .foregroundColor(Palette.subtle)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Palette.subtle)
                }
                .padding(12)
                .background(Palette.card)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(SoftPressStyle())
            .padding(.horizontal, 16)
            .padding(.top, 12)

            HintBlock(text: "预约用「粤苗」App / 微信小程序，可查门诊号源、入学查验、电子接种证。本页仅作家庭记录，实际程序以接种门诊安排为准。")
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
        }
    }

    // MARK: 自选疫苗入口

    private var optionalEntry: some View {
        let picked = store.current?.optVaccines ?? []
        let names = picked.compactMap { Standards.optionalById[$0]?.name }
        return Button {
            showOptional = true
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Palette.purple.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text("💉").font(.system(size: 17))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(picked.isEmpty ? "自选疫苗" : "自选疫苗 · 已选 \(picked.count) 种")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    Text(picked.isEmpty ? "13 价肺炎、五联、轮状、水痘… 勾选后自动加入日程" : names.joined(separator: "、"))
                        .font(.system(size: 11.5))
                        .foregroundColor(Palette.subtle)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Palette.subtle)
            }
            .padding(12)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.hairlineSoft, lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}

// MARK: - 自选疫苗面板

struct OptionalVaccineSheet: View {
    let selected: [String]
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked: Set<String>

    init(selected: [String], onSave: @escaping ([String]) -> Void) {
        self.selected = selected
        self.onSave = onSave
        _picked = State(initialValue: Set(selected))
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Palette.hairline)
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("自选疫苗")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Text("勾选后自动加入日程，相同功效仅建议选一种")
                        .font(.system(size: 12))
                        .foregroundColor(Palette.subtle)
                }
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 21))
                        .foregroundColor(Palette.subtle.opacity(0.5))
                }
                .buttonStyle(SoftPressStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Standards.optionalCatalog) { v in
                        row(v)
                    }
                    HintBlock(text: "价格为常见市场价区间，不同厂家、不同门诊会有差异；是否接种、何时接种请与接种门诊医生沟通。免疫规划疫苗（免费）优先保证。")
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            Button {
                onSave(Standards.optionalCatalog.map(\.id).filter { picked.contains($0) })
                dismiss()
            } label: {
                Text(picked.isEmpty ? "确认（不选自费疫苗）" : "确认添加 \(picked.count) 种")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(picked.isEmpty ? Palette.subtle.opacity(0.45) : Palette.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(SoftPressStyle())
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Palette.background)
        }
        .background(Palette.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func row(_ v: Standards.OptionalVaccine) -> some View {
        let on = picked.contains(v.id)
        return Button {
            if on { picked.remove(v.id) } else { picked.insert(v.id) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(on ? Palette.purple : Palette.hairline, lineWidth: on ? 1.5 : 1.2)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(on ? Palette.purple : Color.clear))
                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(v.name)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundColor(Palette.ink)
                        Text(v.price)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(Palette.purple)
                    }
                    Text(v.desc)
                        .font(.system(size: 11.5))
                        .foregroundColor(Palette.subtle)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(on ? Palette.purple.opacity(0.45) : Palette.hairlineSoft, lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
    }
}

// MARK: - 单剂卡片

struct DoseCard: View {
    let dose: Dose

    private var tone: TagView.Tone {
        switch dose.status {
        case .done: return .ok
        case .due: return .bad
        case .soon: return .warn
        case .pending: return .gray
        }
    }

    private var statusText: String {
        switch dose.status {
        case .done:
            return "已接种" + (dose.doneDate.map { " · " + GrowthMath.dateString($0) } ?? "")
        case .due: return "已到期 · 尽快补种"
        case .soon: return "近期接种"
        case .pending: return "待接种"
        }
    }

    private var borderColor: Color {
        switch dose.status {
        case .due: return Palette.bad.opacity(0.4)
        case .soon: return Palette.warn.opacity(0.4)
        default: return Palette.hairline
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(dose.status == .done ? "✅" : "💉").font(.system(size: 17))
                Text(dose.vaccine.name).font(.system(size: 14.5, weight: .semibold)).foregroundColor(Palette.ink)
                if dose.key.hasPrefix("opt|") {
                    TagView(text: "自费", tone: .warn)
                }
                Spacer()
                TagView(text: dose.vaccine.dose, tone: tone)
            }
            .padding(.horizontal, 15).padding(.vertical, 12)
            .background(dose.status == .done ? Palette.okBg : Palette.purpleTint)

            VStack(spacing: 0) {
                KVRow(key: "建议时间", value: "\(dose.ageLabel)（约 \(GrowthMath.dateString(dose.dueDate))）")
                KVRow(key: "接种途径", value: dose.vaccine.route)
                KVRow(key: "接种部位", value: dose.vaccine.site)
                KVRow(key: "状态", value: statusText, valueColor: dose.status == .done ? Palette.ok : (dose.status == .due ? Palette.bad : Palette.warn))
                Divider().background(Palette.hairlineSoft).padding(.vertical, 6)
                Text("📌 \(dose.vaccine.note)")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.subtle)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(borderColor, lineWidth: 1))
        .opacity(dose.status == .done ? 0.78 : 1)
    }
}

// MARK: - 门诊列表

struct ClinicListView: View {
    @ObservedObject private var library = ClinicLibrary.shared
    @State private var query = ""
    @State private var city = "全部城市"
    @State private var starOnly = false

    private var cityOptions: [String] {
        ["全部城市"] + library.cities()
    }

    private var filtered: [Clinic] {
        library.all.filter { c in
            (city == "全部城市" || c.city == city)
                && (!starOnly || c.star)
                && (query.isEmpty || (c.name + c.address + c.district + c.vaccines).localizedCaseInsensitiveContains(query))
        }
    }

    /// 全量数据时限制一次渲染的条数，保证滚动流畅
    private var visible: [Clinic] {
        let limit = (city == "全部城市" && query.isEmpty) ? 80 : 500
        return Array(filtered.prefix(limit))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                VStack(spacing: 10) {
                    NavigationLink { YamiaoView() } label: {
                        HStack(spacing: 11) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Palette.purple)
                                    .frame(width: 34, height: 34)
                                Image(systemName: "map.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("粤苗官方 · 定位查附近接种门诊")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Palette.ink)
                                Text("省疾控官方名单，定位附近门诊、地图查看，权威实时")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(Palette.subtle)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Palette.subtle)
                        }
                        .padding(11)
                        .background(Palette.purpleTint)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(SoftPressStyle())

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(Palette.subtle)
                        TextField("搜索门诊 / 区 / 路 / 疫苗", text: $query)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Palette.purpleTint)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(cityOptions, id: \.self) { c in
                                Button { city = c } label: { ChipLabel(text: c, selected: city == c) }
                                    .buttonStyle(SoftPressStyle())
                            }
                            Button { starOnly.toggle() } label: {
                                ChipLabel(text: "★ 只看示范门诊", selected: starOnly)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                    Text("共 \(filtered.count) 家" + (visible.count < filtered.count ? " · 当前显示前 \(visible.count) 家，可搜索或选城市" : " · 出发前请电话确认"))
                        .font(.system(size: 12)).foregroundColor(Palette.subtle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .cardStyle(padding: 14)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ForEach(visible) { clinic in
                    NavigationLink { ClinicDetailView(clinic: clinic) } label: {
                        ClinicRow(clinic: clinic)
                    }
                    .buttonStyle(SoftPressStyle())
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }

                HintBlock(text: "本页是离线速查名录（常见门诊地址与电话）。想看周边全部可接种单位，用上面的「粤苗官方 · 定位查附近接种门诊」，官方名单实时定位查询。门诊地址与开诊时间会变动，出发前请电话确认，预约以「粤苗」为准。")
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("接种门诊速查")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ClinicRow: View {
    let clinic: Clinic

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text(clinic.star ? "🏥" : "💉").font(.system(size: 18))
                VStack(alignment: .leading, spacing: 3) {
                    Text(clinic.name).font(.system(size: 14.5, weight: .semibold)).foregroundColor(Palette.ink)
                    Text("\(clinic.city) · \(clinic.district) · \(clinic.tag)")
                        .font(.system(size: 12)).foregroundColor(Palette.subtle)
                }
                Spacer(minLength: 0)
                if clinic.star {
                    TagView(text: "示范", tone: .purple)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("🕐 \(clinic.hours)")
                Text("💉 \(clinic.vaccines)")
                Text("📍 \(clinic.address)")
            }
            .font(.system(size: 12.5))
            .foregroundColor(Palette.ink2)
            .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.hairline, lineWidth: 1))
    }
}

// MARK: - 门诊详情

struct ClinicDetailView: View {
    let clinic: Clinic

    private var scopeText: String {
        clinic.scope.compactMap { Standards.scopeMap[$0] }.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    KVRow(key: "城市 / 区", value: "\(clinic.city) · \(clinic.district)")
                    Divider().background(Palette.hairlineSoft)
                    KVRow(key: "类型", value: clinic.tag)
                    Divider().background(Palette.hairlineSoft)
                    KVRow(key: "接种范围", value: scopeText)
                    Divider().background(Palette.hairlineSoft)
                    KVRow(key: "可接种", value: clinic.vaccines)
                    Divider().background(Palette.hairlineSoft)
                    KVRow(key: "开诊时间", value: clinic.hours)
                    Divider().background(Palette.hairlineSoft)
                    KVRow(key: "地址", value: clinic.address)
                    Divider().background(Palette.hairlineSoft)
                    KVRow(key: "提示", value: clinic.note, valueColor: Palette.warn)
                }
                .cardStyle()

                VStack(spacing: 10) {
                    if let phone = URL(string: "tel://\(clinic.phone.filter { $0.isNumber })") {
                        Link(destination: phone) {
                            Text("📞 打电话 \(clinic.phone)")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(Palette.purple)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 13))
                        }
                    }
                    Button {
                        MapConfig.openNavigation(lat: clinic.lat, lng: clinic.lng, name: clinic.name)
                    } label: {
                        Text("🧭 导航到这里（高德地图）")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(Palette.purpleSoft)
                            .foregroundColor(Palette.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    Button {
                        MapConfig.openMap(lat: clinic.lat, lng: clinic.lng, name: clinic.name)
                    } label: {
                        Text("🗺 在地图上查看")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(Palette.purpleSoft)
                            .foregroundColor(Palette.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    Button {
                        UIPasteboard.general.string = "\(clinic.name)\n\(clinic.address)\n电话：\(clinic.phone)"
                    } label: {
                        Text("📋 复制地址")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(Palette.purpleSoft)
                            .foregroundColor(Palette.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                }

                HintBlock(text: "门诊信息为离线示例数据，开诊时间与号源请以「粤苗」小程序或门诊公示为准。")
            }
            .padding(16)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("门诊详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
