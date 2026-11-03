import SwiftUI

// MARK: - 历史记录

struct HistoryView: View {
    @EnvironmentObject private var store: Store
    @State private var filter = "全部"

    private enum Item: Identifiable {
        case record(GrowthRecord)
        case feed(FeedLog)
        case size(SizeRecord)

        var id: String {
            switch self {
            case .record(let r): return "r-\(r.id)"
            case .feed(let f): return "f-\(f.id)"
            case .size(let s): return "s-\(s.id)"
            }
        }

        var date: Date {
            switch self {
            case .record(let r): return r.date
            case .feed(let f): return f.date
            case .size(let s): return s.date
            }
        }

        var kind: String {
            switch self {
            case .record: return "生长"
            case .feed: return "喂养"
            case .size: return "鞋服"
            }
        }
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
        .navigationTitle("历史记录")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ child: Child) -> some View {
        var items: [Item] = []
        items.append(contentsOf: child.records.map { Item.record($0) })
        // 喂养模块隐藏后，喂养类历史（奶量/亲喂/吸奶/尿布/睡眠/辅食/补剂）一并隐藏；体温和自定义记录保留
        if store.settings.showFeed {
            items.append(contentsOf: child.feeds.map { Item.feed($0) })
        } else {
            items.append(contentsOf: child.feeds.filter { $0.kind == .temp || $0.kind == .custom }.map { Item.feed($0) })
        }
        if store.settings.showSize { items.append(contentsOf: child.sizes.filter { $0.hasContent }.map { Item.size($0) }) }
        items.sort { $0.date > $1.date }

        let visible = filter == "全部" ? items : items.filter { $0.kind == filter }
        let filters = store.settings.showFeed ? ["全部", "生长", "喂养", "鞋服"] : ["全部", "生长", "鞋服"]

        return VStack(spacing: 0) {
            HStack {
                Text(child.name).font(.system(size: 16, weight: .bold)).foregroundColor(Palette.ink)
                Spacer()
                Text("\(visible.count) 条记录").font(.system(size: 12)).foregroundColor(Palette.subtle)
            }
            .padding(.horizontal, 18).padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { f in
                        Button { filter = f } label: { ChipLabel(text: f, selected: filter == f) }
                            .buttonStyle(SoftPressStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 10)

            if visible.isEmpty {
                EmptyHint(text: "该分类下还没有记录")
            } else {
                ForEach(visible) { item in
                    itemView(item, child: child)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }
            }
            Spacer(minLength: 28)
        }
    }

    @ViewBuilder
    private func itemView(_ item: Item, child: Child) -> some View {
        switch item {
        case .record(let record):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TagView(text: "生长", tone: .purple)
                    Text(GrowthMath.dateString(record.date)).font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.ink2)
                    Text(GrowthMath.ageText(from: child.birthDate, to: record.date)).font(.system(size: 12)).foregroundColor(Palette.subtle)
                    Spacer()
                    Button { store.deleteRecord(record.id) } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundColor(Palette.bad)
                    }
                    .buttonStyle(SoftPressStyle())
                }
                RecordMiniCard(child: child, record: record, weightUnit: store.settings.weightUnit)
                    .padding(.horizontal, -0)
            }
        case .feed(let log):
            HStack(spacing: 10) {
                Text(log.kind.icon).font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(log.kind.title) · \(log.summary)").font(.system(size: 14)).foregroundColor(Palette.ink)
                    Text("\(GrowthMath.dateString(log.date)) \(log.date.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                }
                Spacer()
                Button { store.deleteFeed(log.id) } label: {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundColor(Palette.bad)
                }
                .buttonStyle(SoftPressStyle())
            }
            .padding(14)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.hairline, lineWidth: 1))
        case .size(let size):
            let s = GrowthMath.shoeSize(foot: size.footLength, height: size.height)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    TagView(text: "鞋服", tone: .gray)
                    Text(GrowthMath.dateString(size.date)).font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.ink2)
                    Spacer()
                    Button { store.deleteSize(size.id) } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundColor(Palette.bad)
                    }
                    .buttonStyle(SoftPressStyle())
                }
                if let cn = s.cn, let eu = s.eu {
                    Text("脚长 \(String(format: "%.1f", size.footLength ?? 0))cm → 中国码 \(cn) / 欧码 \(eu)")
                        .font(.system(size: 13.5)).foregroundColor(Palette.ink)
                }
                if let top = s.top, let pant = s.pant {
                    Text("上衣 \(top) · 裤子 \(pant)").font(.system(size: 13.5)).foregroundColor(Palette.ink)
                }
                // 手填的身体/衣物尺寸
                let manual: [String] = {
                    var parts: [String] = []
                    func add(_ label: String, _ v: Double?, unit: String = "cm") {
                        guard let v else { return }
                        parts.append("\(label) \(String(format: "%.1f", v))\(unit)")
                    }
                    add("肩宽", size.shoulder)
                    add("腰围", size.waist)
                    add("臀围", size.hip)
                    add("大腿围", size.thigh)
                    add("小腿围", size.calf)
                    add("衣长", size.topLength)
                    add("袖长", size.sleeve)
                    add("裤长", size.pantsLength)
                    if let v = size.shoeSize { parts.append("穿鞋 \(v) 码") }
                    add("鞋内长", size.shoeInner)
                    return parts
                }()
                if !manual.isEmpty {
                    Text(manual.joined(separator: " · "))
                        .font(.system(size: 12.5)).foregroundColor(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !size.note.isEmpty {
                    Text(size.note).font(.system(size: 12)).foregroundColor(Palette.subtle)
                }
            }
            .padding(14)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.hairline, lineWidth: 1))
        }
    }
}
