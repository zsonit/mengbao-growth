import SwiftUI

// MARK: - 横向标尺选择器（指针固定，刻度跟着手指走）

/// 用法：RulerPicker(value: $ml, range: 0...300, step: 5, format: "%.0f", unit: "ml")
struct RulerPicker: View {
    @Binding var value: Double

    var range: ClosedRange<Double>
    var step: Double
    /// 气泡与刻度数字的格式，例如 "%.0f" / "%.1f" / "%.2f"
    var format: String = "%.0f"
    var unit: String = ""
    var accent: Color = Palette.purple

    /// 一个刻度占的宽度（pt）
    private let tickSpacing: CGFloat = 10
    /// 最多画多少个刻度，避免体重这种上千格的范围卡住界面
    private let maxTicks = 150

    /// 一次拖动开始时的值，拖动过程按「起点 + 位移」算，拖到边缘再拖回来不会跑偏
    @State private var dragStart: Double? = nil

    // MARK: 派生量

    private var stepValue: Double { step > 0 ? step : 1 }
    private var lower: Double { range.lowerBound }

    /// 防御：range 传反了也不崩
    private var upperBoundSafe: Double {
        range.upperBound > range.lowerBound ? range.upperBound : range.lowerBound + stepValue
    }

    private var totalSteps: Int {
        max(1, Int(((upperBoundSafe - lower) / stepValue).rounded()))
    }

    /// 每隔多少个 step 画一个刻度
    private var tickEvery: Int {
        max(1, Int((Double(totalSteps) / Double(maxTicks - 1)).rounded(.up)))
    }

    /// 多画一格，保证拖到最大值时右边仍有刻度
    private var tickCount: Int { totalSteps / tickEvery + 2 }

    /// 一个 step 对应的像素宽度
    private var pixelsPerStep: CGFloat { tickSpacing / CGFloat(tickEvery) }

    private var contentWidth: CGFloat { CGFloat(tickCount) * tickSpacing }

    private var currentIndex: Double { (value - lower) / stepValue }

    /// 让当前值对应的刻度正好落在中间的偏移量
    private var offsetX: CGFloat {
        let index = currentIndex / Double(tickEvery)
        return tickSpacing * (CGFloat(tickCount) / 2 - 0.5 - CGFloat(index))
    }

    private var bubbleText: String {
        let number = String(format: format, value)
        return unit.isEmpty ? number : number + " " + unit
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 10) {
            Text(bubbleText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(accent))
                .shadow(color: accent.opacity(0.3), radius: 6, y: 3)

            GeometryReader { geo in
                ZStack {
                    HStack(spacing: 0) {
                        ForEach(0..<tickCount, id: \.self) { i in
                            tickView(i)
                        }
                    }
                    .frame(width: contentWidth, height: 36)
                    .offset(x: offsetX)

                    // 中间指针
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(accent)
                        .frame(width: 2.5, height: 32)
                }
                .frame(width: geo.size.width, height: 36)
                .contentShape(Rectangle())
                .clipped()
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            if dragStart == nil { dragStart = value }
                            let base = dragStart ?? value
                            let delta = -Double(g.translation.width / pixelsPerStep) * stepValue
                            value = snapped(base + delta)
                        }
                        .onEnded { _ in
                            dragStart = nil
                        }
                )
            }
            .frame(height: 36)
        }
        .onAppear {
            // 保证初值落在范围里、并且对齐到 step
            value = snapped(value)
        }
    }

    // MARK: 刻度

    private func tickView(_ i: Int) -> some View {
        let isMajor = i % 5 == 0
        let tickValue = lower + Double(i * tickEvery) * stepValue
        return VStack(spacing: 0) {
            Text(isMajor ? String(format: format, tickValue) : " ")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Palette.subtle)
                .lineLimit(1)
                .fixedSize()
                .frame(height: 12)
            Rectangle()
                .fill(isMajor ? Palette.subtle.opacity(0.45) : Palette.hairline)
                .frame(width: isMajor ? 1.4 : 1, height: isMajor ? 16 : 8)
            Spacer(minLength: 0)
        }
        .frame(width: tickSpacing, height: 36, alignment: .top)
    }

    // MARK: 吸附

    private func snapped(_ raw: Double) -> Double {
        guard raw.isFinite else { return lower }
        let index = ((raw - lower) / stepValue).rounded()
        let clamped = min(upperBoundSafe, max(lower, lower + index * stepValue))
        // 消掉 0.05 这类步长累积的浮点误差
        return (clamped * 100000).rounded() / 100000
    }
}
