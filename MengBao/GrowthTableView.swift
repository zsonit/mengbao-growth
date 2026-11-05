import SwiftUI

// MARK: - 数据表格：百分位对照表（身高 / 体重 / BMI，逐月 0–18 岁）

struct GrowthTableView: View {
    @EnvironmentObject private var store: Store
    let initialMetric: GrowthMetric

    @State private var metric: GrowthMetric = .height
    @State private var didInit = false
    @State private var didScroll = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let child = store.current {
                    content(child)
                } else {
                    EmptyHint(text: "先添加宝宝档案")
                }
            }
            .background(Palette.background.ignoresSafeArea())
            .onAppear {
                if !didInit {
                    didInit = true
                    metric = initialMetric
                }
                if let child = store.current, !didScroll {
                    didScroll = true
                    let current = GrowthMath.ageMonths(from: child.birthDate)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(Anim.soft) {
                            proxy.scrollTo(current, anchor: .center)
                        }
                    }
                }
            }
        }
        .navigationTitle("数据表格")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ child: Child) -> some View {
        // 各月龄的实测值（身高 / 体重 / BMI 按指标取）
        var values: [Int: Double] = [:]
        for record in child.sortedRecords {
            let m = GrowthMath.ageMonths(from: child.birthDate, to: record.date)
            let v: Double?
            switch metric {
            case .height: v = record.height
            case .weight: v = record.weight
            case .bmi:
                if let h = record.height, let w = record.weight {
                    v = GrowthMath.bmiValue(height: h, weight: w)
                } else {
                    v = nil
                }
            }
            if let v = v { values[m] = v }
        }

        return LazyVStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ForEach(GrowthMetric.allCases) { m in
                    Button { withAnimation(Anim.tap) { metric = m } } label: {
                        ChipLabel(text: m.rawValue, selected: metric == m)
                    }
                    .buttonStyle(SoftPressStyle())
                }
                Spacer()
                Text(GrowthMath.ageText(from: child.birthDate))
                    .font(.system(size: 11.5)).foregroundColor(Palette.subtle)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // 表头
            HStack(spacing: 0) {
                Text("年龄").frame(width: 72, alignment: .leading)
                ForEach(["P3", "P15", "P50", "P85", "P97"], id: \.self) { p in
                    Text(p).frame(maxWidth: .infinity)
                }
                Text(metric.rawValue).frame(width: 56)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Palette.ink2)
            .padding(.vertical, 9)
            .background(Palette.hairlineSoft.opacity(0.4))
            .padding(.horizontal, 16)

            // 逐月行：0 ~ 216 月
            let currentMonths = GrowthMath.ageMonths(from: child.birthDate)
            ForEach(0...216, id: \.self) { m in
                tableRow(child: child, months: m, values: values, currentMonths: currentMonths)
                    .id(m)
            }

            Text("百分位说明：P3 表示同龄同性别孩子中约 3% 的水平，P50 为中位数，以此类推。带「现在」标记的紫色行是宝宝当前月龄。0–18 岁身高体重采用首都儿科研究所《0~18岁儿童青少年身高、体重百分位数值表》（李辉），BMI 采用 WHO 及 WS/T 相关标准。")
                .font(.system(size: 11.5))
                .foregroundColor(Palette.subtle)
                .lineSpacing(4)
                .padding(14)
        }
    }

    private func tableRow(child: Child, months: Int, values: [Int: Double], currentMonths: Int) -> some View {
        let isCurrent = months == currentMonths
        let bands = GrowthMath.refBands(sex: child.sex, metric: metric, months: months)
        let value = values[months]
        // 数值落在哪一档百分位：0=P3 档内 … 4=≥P97
        let hit: Int? = value.map { v in
            for i in 0..<5 {
                let upper = i < 4 ? bands[i + 1] : Double.infinity
                if v >= bands[i] && v < upper { return i }
            }
            return 4
        }
        let fmt = value.map { String(format: "%.1f", $0) } ?? ""

        return HStack(spacing: 0) {
            if isCurrent {
                Capsule()
                    .fill(Palette.purple)
                    .frame(width: 3.5)
                    .padding(.vertical, 4)
            }
            HStack(spacing: 4) {
                Text(ageLabel(months))
                    .font(.system(size: 12, weight: isCurrent || value != nil ? .bold : .regular))
                    .foregroundColor(value != nil ? Palette.ink : Palette.ink2)
                if isCurrent {
                    Text("现在")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Palette.purple))
                }
            }
            .frame(width: isCurrent ? 68 : 72, alignment: .leading)
            ForEach(0..<5, id: \.self) { i in
                Text(String(format: "%.1f", bands[i]))
                    .font(.system(size: 12, weight: hit == i ? .bold : .regular))
                    .foregroundColor(hit == i ? Palette.purple : Palette.ink2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(hit == i ? Palette.purple.opacity(0.14) : Color.clear)
            }
            Text(fmt)
                .font(.system(size: 12, weight: value != nil ? .bold : .regular))
                .foregroundColor(Palette.ink)
                .frame(width: 56)
        }
        .padding(.horizontal, 16)
        .background(
            isCurrent ? Palette.purple.opacity(0.09)
            : (value != nil ? Palette.purpleSoft.opacity(0.5) : Color.clear)
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairlineSoft).frame(height: 0.5)
        }
    }

    /// 月龄 → 表格行标签：出生 / 6月 / 11岁 / 10岁6月
    private func ageLabel(_ months: Int) -> String {
        if months == 0 { return "出生" }
        if months < 12 { return "\(months)月" }
        let y = months / 12, m = months % 12
        return m == 0 ? "\(y)岁" : "\(y)岁\(m)月"
    }
}
