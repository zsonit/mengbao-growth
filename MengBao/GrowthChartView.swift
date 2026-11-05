import SwiftUI

/// 生长曲线：百分位带 + 参考线 + 实测折线（纯 Canvas 手绘，无第三方依赖）
struct GrowthChartView: View {
    let child: Child
    let metric: GrowthMetric

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

    var body: some View {
        Canvas { context, size in
            let padLeft: CGFloat = 34, padRight: CGFloat = 14, padTop: CGFloat = 16, padBottom: CGFloat = 26
            let plotW = size.width - padLeft - padRight
            let plotH = size.height - padTop - padBottom
            guard plotW > 10, plotH > 10 else { return }

            let latestMonth = points.map { $0.month }.max() ?? 0
            let maxMonth = max(36, min(216, latestMonth + 6))

            var low = Double.greatestFiniteMagnitude
            var high = -Double.greatestFiniteMagnitude
            var m = 0
            while m <= maxMonth {
                let band = GrowthMath.chartBands(sex: child.sex, metric: metric, months: m)
                low = min(low, band[0])
                high = max(high, band[4])
                m += 3
            }
            for p in points {
                low = min(low, p.value)
                high = max(high, p.value)
            }
            if !low.isFinite || !high.isFinite { return }

            // 纵向范围取整
            let span = max(1, high - low)
            let step = pow(10, floor(log10(span))) / 2
            let yMin = floor(low * 0.96 / step) * step
            let yMax = ceil(high * 1.02 / step) * step

            func x(_ month: Int) -> CGFloat { padLeft + CGFloat(month) / CGFloat(maxMonth) * plotW }
            func y(_ value: Double) -> CGFloat { padTop + plotH - CGFloat((value - yMin) / (yMax - yMin)) * plotH }

            // 网格
            let gridColor = Palette.hairline
            var tickStep = 6
            if maxMonth > 36 { tickStep = 12 }
            if maxMonth > 84 { tickStep = 24 }
            var tick = 0
            while tick <= maxMonth {
                var path = Path()
                path.move(to: CGPoint(x: x(tick), y: padTop))
                path.addLine(to: CGPoint(x: x(tick), y: padTop + plotH))
                context.stroke(path, with: .color(gridColor), lineWidth: 1)
                let label = tick == 0 ? "0" : (tick % 12 == 0 ? "\(tick / 12)岁" : "\(tick)月")
                context.draw(Text(label).font(.system(size: 9)).foregroundColor(Palette.subtle),
                             at: CGPoint(x: x(tick), y: size.height - 8), anchor: .bottom)
                tick += tickStep
            }

            var yTick = yMin
            let yTickStep = (yMax - yMin) / 4
            if yTickStep > 0 {
                while yTick <= yMax + 0.0001 {
                    var path = Path()
                    path.move(to: CGPoint(x: padLeft, y: y(yTick)))
                    path.addLine(to: CGPoint(x: size.width - padRight, y: y(yTick)))
                    context.stroke(path, with: .color(gridColor), lineWidth: 1)
                    let label = metric == .height ? "\(Int(yTick.rounded()))" : String(format: "%.1f", yTick)
                    context.draw(Text(label).font(.system(size: 9)).foregroundColor(Palette.subtle),
                                 at: CGPoint(x: padLeft - 6, y: y(yTick)), anchor: .trailing)
                    yTick += yTickStep
                }
            }

            // 百分位带
            func bandPath(_ lowerIndex: Int, _ upperIndex: Int) -> Path {
                var path = Path()
                var first = true
                var month = 0
                while month <= maxMonth {
                    let v = GrowthMath.chartBands(sex: child.sex, metric: metric, months: month)[upperIndex]
                    let pt = CGPoint(x: x(month), y: y(v))
                    if first { path.move(to: pt); first = false } else { path.addLine(to: pt) }
                    month += 3
                }
                var back = maxMonth - (maxMonth % 3)
                while back >= 0 {
                    let v = GrowthMath.chartBands(sex: child.sex, metric: metric, months: back)[lowerIndex]
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
                    let v = GrowthMath.chartBands(sex: child.sex, metric: metric, months: month)[style.index]
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
                               style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
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
                if bx + boxWidth > size.width - padRight { bx = center.x - boxWidth - 9 }
                let by = max(padTop, center.y - 26)
                let rect = CGRect(x: bx, y: by, width: boxWidth, height: 17)
                context.fill(Path(roundedRect: rect, cornerRadius: 8.5), with: .color(Palette.ok.opacity(0.95)))
                context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
            }
        }
        .background(Palette.card)
    }
}
