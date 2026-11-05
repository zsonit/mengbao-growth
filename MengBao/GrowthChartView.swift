import SwiftUI

/// 生长曲线：百分位带 + 参考线 + 实测折线（纯 Canvas 手绘，无第三方依赖）
/// 横向按「每月固定宽度」铺开，可左右滑动查看，Y 轴固定在左侧不随图滚动。
struct GrowthChartView: View {
    let child: Child
    let metric: GrowthMetric

    /// 每个月占的横向宽度（pt）：越大曲线越舒展
    private let pxPerMonth: CGFloat = 8
    private let padTop: CGFloat = 16
    private let padBottom: CGFloat = 26
    private let padRight: CGFloat = 14
    private let yAxisWidth: CGFloat = 36

    private var points: [(month: Int, value: Double, date: Date)] {
        child.sortedRecords.compactMap { record in
            let months = GrowthMath.ageMonths(from: child.birthDate, to: record.date)
            switch metric {
            case .height:
                guard let h = record.height else { return nil }
                return (months, h, record.date)
            case .weight:
                guard let w = record.weight else { return nil }
                return (months, w, record.date)
            case .bmi:
                guard let h = record.height, let w = record.weight else { return nil }
                return (months, GrowthMath.bmiValue(height: h, weight: w), record.date)
            }
        }
    }

    private var maxMonth: Int {
        max(36, min(216, (points.map { $0.month }.max() ?? 0) + 6))
    }

    /// 纵向范围（取整后），两份 Canvas 共用同一套范围才能对齐
    private var yRange: (low: Double, high: Double)? {
        var low = Double.greatestFiniteMagnitude
        var high = -Double.greatestFiniteMagnitude
        var m = 0
        while m <= maxMonth {
            let band = GrowthMath.refBands(sex: child.sex, metric: metric, months: m)
            low = min(low, band[0])
            high = max(high, band[4])
            m += 3
        }
        for p in points {
            low = min(low, p.value)
            high = max(high, p.value)
        }
        if !low.isFinite || !high.isFinite { return nil }

        let span = max(1, high - low)
        let step = pow(10, floor(log10(span))) / 2
        let yMin = floor(low * 0.96 / step) * step
        let yMax = ceil(high * 1.02 / step) * step
        guard yMax > yMin else { return nil }
        return (yMin, yMax)
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let visiblePlot = geo.size.width - yAxisWidth
            // 每月固定宽度，最窄也铺满卡片可视宽度
            let plotW = max(visiblePlot, CGFloat(maxMonth) * pxPerMonth + padRight)

            HStack(spacing: 0) {
                yAxis(height: h)
                    .frame(width: yAxisWidth)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            plot(width: plotW, height: h)
                            Color.clear
                                .frame(width: 1, height: h)
                                .id("tail")
                        }
                    }
                    .onAppear {
                        // 默认滚到最右（最新数据一侧）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            proxy.scrollTo("tail", anchor: .trailing)
                        }
                    }
                }
            }
        }
        .background(Palette.card)
    }

    // MARK: - 左侧固定 Y 轴

    private func yAxis(height: CGFloat) -> some View {
        Canvas { context, size in
            guard let range = yRange else { return }
            let plotH = height - padTop - padBottom
            guard plotH > 10 else { return }

            func y(_ value: Double) -> CGFloat {
                padTop + plotH - CGFloat((value - range.low) / (range.high - range.low)) * plotH
            }

            var tick = range.low
            let step = (range.high - range.low) / 4
            guard step > 0 else { return }
            while tick <= range.high + 0.0001 {
                var path = Path()
                path.move(to: CGPoint(x: size.width - 3, y: y(tick)))
                path.addLine(to: CGPoint(x: size.width, y: y(tick)))
                context.stroke(path, with: .color(Palette.hairline), lineWidth: 1)

                let label = metric == .height ? "\(Int(tick.rounded()))" : String(format: "%.1f", tick)
                context.draw(Text(label).font(.system(size: 10)).foregroundColor(Palette.subtle),
                             at: CGPoint(x: size.width - 6, y: y(tick)), anchor: .trailing)
                tick += step
            }
        }
        .background(Palette.card)
    }

    // MARK: - 可横向滚动的绘图区

    private func plot(width plotW: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            guard let range = yRange else { return }
            let plotH = height - padTop - padBottom
            let drawW = plotW - padRight
            guard drawW > 10, plotH > 10 else { return }

            func x(_ month: Int) -> CGFloat { CGFloat(month) / CGFloat(maxMonth) * drawW }
            func y(_ value: Double) -> CGFloat {
                padTop + plotH - CGFloat((value - range.low) / (range.high - range.low)) * plotH
            }

            // 纵向网格 + 横轴刻度
            let tickStep = maxMonth <= 36 ? 6 : 12
            var tick = 0
            while tick <= maxMonth {
                var path = Path()
                path.move(to: CGPoint(x: x(tick), y: padTop))
                path.addLine(to: CGPoint(x: x(tick), y: padTop + plotH))
                context.stroke(path, with: .color(Palette.hairline), lineWidth: 1)

                let label = tick == 0 ? "0" : (tick % 12 == 0 ? "\(tick / 12)岁" : "\(tick)月")
                context.draw(Text(label).font(.system(size: 9)).foregroundColor(Palette.subtle),
                             at: CGPoint(x: x(tick), y: size.height - 8), anchor: .bottom)
                tick += tickStep
            }

            // 横向网格
            var yTick = range.low
            let yStep = (range.high - range.low) / 4
            if yStep > 0 {
                while yTick <= range.high + 0.0001 {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y(yTick)))
                    path.addLine(to: CGPoint(x: drawW, y: y(yTick)))
                    context.stroke(path, with: .color(Palette.hairline), lineWidth: 1)
                    yTick += yStep
                }
            }

            // 百分位带
            func bandPath(_ lowerIndex: Int, _ upperIndex: Int) -> Path {
                var path = Path()
                var first = true
                var month = 0
                while month <= maxMonth {
                    let v = GrowthMath.refBands(sex: child.sex, metric: metric, months: month)[upperIndex]
                    let pt = CGPoint(x: x(month), y: y(v))
                    if first { path.move(to: pt); first = false } else { path.addLine(to: pt) }
                    month += 3
                }
                var back = maxMonth - (maxMonth % 3)
                while back >= 0 {
                    let v = GrowthMath.refBands(sex: child.sex, metric: metric, months: back)[lowerIndex]
                    path.addLine(to: CGPoint(x: x(back), y: y(v)))
                    back -= 3
                }
                path.closeSubpath()
                return path
            }

            context.fill(bandPath(0, 4), with: .color(Palette.purple.opacity(0.07)))
            context.fill(bandPath(1, 3), with: .color(Palette.purple.opacity(0.12)))

            // 百分位线
            let styles: [(index: Int, color: Color, dash: [CGFloat], width: CGFloat)] = [
                (0, Color(hex: 0xE0513A), [5, 4], 1.2),
                (1, Color(hex: 0xE2A33C), [4, 3], 1.2),
                (2, Palette.purple, [], 2),
                (3, Color(hex: 0xE2A33C), [4, 3], 1.2),
                (4, Color(hex: 0xE0513A), [5, 4], 1.2)
            ]
            for style in styles {
                var path = Path()
                var month = 0
                var first = true
                while month <= maxMonth {
                    let v = GrowthMath.refBands(sex: child.sex, metric: metric, months: month)[style.index]
                    let pt = CGPoint(x: x(month), y: y(v))
                    if first { path.move(to: pt); first = false } else { path.addLine(to: pt) }
                    month += 3
                }
                context.stroke(path, with: .color(style.color),
                               style: StrokeStyle(lineWidth: style.width, dash: style.dash))
            }

            // 实测折线
            let sorted = points.sorted { $0.month < $1.month }
            if sorted.count > 1 {
                var path = Path()
                for (idx, p) in sorted.enumerated() {
                    let pt = CGPoint(x: x(p.month), y: y(p.value))
                    if idx == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                context.stroke(path, with: .color(Palette.ok),
                               style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            }
            for p in sorted {
                let center = CGPoint(x: x(p.month), y: y(p.value))
                let dot = Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
                context.fill(dot, with: .color(Palette.card))
                context.stroke(dot, with: .color(Palette.ok), lineWidth: 2.2)
            }

            // 末点标注
            if let last = sorted.last {
                let label = metric == .height
                    ? "\(Int(last.value.rounded()))cm"
                    : String(format: "%.1f%@", last.value, metric.unit)
                let center = CGPoint(x: x(last.month), y: y(last.value))
                let text = Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(.white)
                let boxWidth: CGFloat = metric == .height ? 46 : 44
                var bx = center.x + 9
                if bx + boxWidth > drawW { bx = center.x - boxWidth - 9 }
                bx = max(0, bx)
                let by = max(padTop, center.y - 26)
                let rect = CGRect(x: bx, y: by, width: boxWidth, height: 17)
                context.fill(Path(roundedRect: rect, cornerRadius: 8.5), with: .color(Palette.ok.opacity(0.95)))
                context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
            }
        }
        .frame(width: plotW, height: height)
    }
}
