import SwiftUI

// MARK: - 接种计划

struct VaccineView: View {
    @EnvironmentObject private var store: Store

    private let ageFilters: [(String, ClosedRange<Int>?)] = [
        ("全部", nil), ("0 岁", 0...11), ("1 岁", 12...17), ("2 岁", 18...35),
        ("3 岁", 36...47), ("4 岁", 48...71), ("6 岁", 72...400)
    ]

    @State private var filter = "全部"

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
    }

    private func content(_ child: Child) -> some View {
        let schedule = GrowthMath.schedule(for: child)
        let done = schedule.filter { $0.status == .done }.count
        let due = schedule.filter { $0.status == .due }.count
        let total = GrowthMath.totalDoses
        let percent = Int(Double(done) / Double(max(total, 1)) * 100)
        let next = schedule.first { $0.status == .soon }
        let range = ageFilters.first { $0.0 == filter }?.1
        let visible = range == nil ? schedule : schedule.filter { range!.contains($0.months) }

        return VStack(spacing: 0) {
            // Hero
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Text(child.displayAvatar).font(.system(size: 24))
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white.opacity(0.24)))
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(child.name).font(.system(size: 19, weight: .bold))
                        Text("\(GrowthMath.ageText(from: child.birthDate)) · 广东执行国家免疫规划")
                            .font(.system(size: 12)).opacity(0.95)
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    Text("📍 接种进度").font(.system(size: 12.5))
                    Spacer()
                    Text("\(percent)% 完成").font(.system(size: 12.5, weight: .semibold))
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.18)))
                .padding(.top, 14)

                NavigationLink { ClinicListView() } label: {
                    Text("🗺 查看附近接种门诊 →")
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
                KVRow(key: "适用标准", value: "国家免疫规划 2025 版")
            }
            .cardStyle(padding: 14)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ageFilters, id: \.0) { item in
                        Button { filter = item.0 } label: {
                            ChipLabel(text: item.0, selected: filter == item.0)
                        }
                        .buttonStyle(.plain)
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
                    store.toggleShot(key: dose.key)
                } label: {
                    DoseCard(dose: dose)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 9)
            }

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

            HintBlock(text: "预约用「粤苗」App / 微信小程序，可查门诊号源、入学查验、电子接种证。本页仅作家庭记录，实际程序以接种门诊安排为准。")
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
        }
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
    @State private var query = ""
    @State private var city = "全部城市"
    @State private var starOnly = false

    private let cities = ["全部城市", "广州", "深圳", "佛山", "东莞", "珠海", "中山", "惠州", "汕头", "湛江"]

    private var filtered: [Clinic] {
        Standards.clinics.filter { c in
            (city == "全部城市" || c.city == city)
                && (!starOnly || c.star)
                && (query.isEmpty || (c.name + c.address + c.district + c.vaccines).localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    NavigationLink { NearbyClinicsView() } label: {
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
                                Text("附近接种门诊 · 地图定位")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Palette.ink)
                                Text("按当前位置搜最近的接种点，可一键导航")
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
                    .buttonStyle(.plain)

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
                            ForEach(cities, id: \.self) { c in
                                Button { city = c } label: { ChipLabel(text: c, selected: city == c) }
                                    .buttonStyle(.plain)
                            }
                            Button { starOnly.toggle() } label: {
                                ChipLabel(text: "★ 只看示范门诊", selected: starOnly)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("共 \(filtered.count) 家 · 数据为离线示例，出发前请电话确认")
                        .font(.system(size: 12)).foregroundColor(Palette.subtle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .cardStyle(padding: 14)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ForEach(filtered) { clinic in
                    NavigationLink { ClinicDetailView(clinic: clinic) } label: {
                        ClinicRow(clinic: clinic)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }

                HintBlock(text: "门诊地址、开诊时间与号源实时变动，出发前请电话确认。离线数据来自广东省疾控与各市卫健委公开信息，仅供出行参考。")
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("接种门诊")
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
