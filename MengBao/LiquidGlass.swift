import SwiftUI
import UIKit

// MARK: - 全局动效基调
//
// 之前整个 App 基本都是「状态一变就切换」，缺少中间过渡，所以看着生硬。
// 这里统一规定几档弹簧：轻点、页面、Tab、浮层，各页面只引用这里，不再各写 easeInOut。

enum Anim {
    /// 轻点反馈：短促、有回弹但不过冲
    static let tap = Animation.spring(response: 0.30, dampingFraction: 0.72)
    /// 页面切换：稍慢、带一点粘滞感
    static let page = Animation.spring(response: 0.46, dampingFraction: 0.86)
    /// Tab 选中胶囊滑动
    static let tab = Animation.spring(response: 0.42, dampingFraction: 0.74)
    /// 浮层 / 面板出现
    static let pop = Animation.spring(response: 0.38, dampingFraction: 0.80)
    /// 通用柔化
    static let soft = Animation.spring(response: 0.42, dampingFraction: 0.88)

    /// 轻触震动：玻璃感的另一半是触觉，配合动画一起出现
    static func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.prepare()
        g.impactOccurred()
    }
}

/// 按下即缩小的按钮样式，替代系统生硬的高亮
struct SoftPressStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    var dim: Double = 0.88
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? dim : 1)
            .animation(Anim.tap, value: configuration.isPressed)
    }
}

extension View {
    /// 出现时轻微上浮淡入
    func softAppear(delay: Double = 0) -> some View {
        modifier(SoftAppear(delay: delay))
    }
}

private struct SoftAppear: ViewModifier {
    let delay: Double
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 12)
            .onAppear {
                guard !on else { return }
                withAnimation(Anim.soft.delay(delay)) { on = true }
            }
    }
}

// MARK: - 液态玻璃（Liquid Glass）材质
//
// 参照 iOS 26/27 液态玻璃观感：半透明材质 + 顶部受光高光 + 内描边（上亮下暗）+ 底部内阴影 + 柔和外投影。
// 有意不调用 `.glassEffect()`（那是 iOS 26 SDK 才有的符号，CI 的 Xcode 版本不受控），
// 用系统 `.ultraThinMaterial` 手工叠出来，iOS 16 起全部可用，新旧系统观感一致。

extension View {
    /// 给任意内容包一层液态玻璃背景
    /// - Parameters:
    ///   - shape: 玻璃形状（胶囊 / 圆角矩形都行）
    ///   - intensity: 高光强度，0～1
    func liquidGlass<S: Shape>(in shape: S, intensity: Double = 1.0) -> some View {
        self.modifier(LiquidGlassModifier(shape: shape, intensity: intensity))
    }
}

struct LiquidGlassModifier<S: Shape>: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let shape: S
    let intensity: Double

    func body(content: Content) -> some View {
        let light = scheme == .light
        let hiTop = (light ? 0.62 : 0.18) * intensity
        let hiMid = (light ? 0.20 : 0.05) * intensity
        let hiBottom = (light ? 0.05 : 0.02) * intensity
        let edgeTop = (light ? 0.95 : 0.30) * intensity
        let edgeBottom = (light ? 0.18 : 0.08) * intensity

        return content
            .background(
                ZStack {
                    // 1) 折射底：系统毛玻璃
                    shape.fill(.ultraThinMaterial)
                    // 2) 顶光：上亮 -> 中透 -> 下暗，玻璃的厚度感
                    shape.fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(hiTop), location: 0.0),
                                .init(color: .white.opacity(hiMid), location: 0.48),
                                .init(color: .white.opacity(hiBottom), location: 1.0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    // 3) 内描边：上缘受光、下缘收暗
                    shape.stroke(
                        LinearGradient(
                            colors: [.white.opacity(edgeTop), .white.opacity(edgeBottom)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    // 4) 底缘内侧的一线反光，玻璃「厚边」的关键
                    //    （注意：泛型 Shape 没有 inset，不能用 inset(by:)，用偏移描边 + 模糊近似）
                    shape
                        .stroke(Color.white.opacity(light ? 0.38 : 0.12), lineWidth: 2.5)
                        .blur(radius: 2.5)
                        .offset(y: 1.5)
                        .mask(shape)
                }
            )
            .shadow(color: .black.opacity(scheme == .light ? 0.10 : 0.34), radius: 18, x: 0, y: 8)
            .shadow(color: .black.opacity(scheme == .light ? 0.05 : 0.18), radius: 3, x: 0, y: 1)
    }
}

// MARK: - 悬浮液态玻璃 Tab 栏（iOS 26 风格）

struct LiquidTabBar: View {
    struct Item: Identifiable {
        let id: String
        let label: String
        let icon: String
    }

    let items: [Item]
    @Binding var selection: String

    @Environment(\.colorScheme) private var scheme
    @Namespace private var pillNS
    /// 高光扫过的位置：切换页签时斜掠一次，营造液体流动感
    @State private var sweep: CGFloat = -1.2

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                itemButton(item)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .liquidGlass(in: Capsule())
        .overlay(sheen)
        .padding(.horizontal, 22)
        .padding(.bottom, 2)
    }

    // MARK: 单个页签

    private func itemButton(_ item: Item) -> some View {
        let selected = item.id == selection
        return Button {
            guard !selected else { return }
            Anim.haptic(.soft)
            withAnimation(Anim.tab) { selection = item.id }
            // 高光斜掠
            sweep = -1.2
            withAnimation(.easeOut(duration: 0.55)) { sweep = 1.2 }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: 18.5, weight: selected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(selected ? 1.07 : 1.0)
                    .offset(y: selected ? -0.5 : 0)
                Text(item.label)
                    .font(.system(size: 10, weight: selected ? .semibold : .medium))
                    .opacity(selected ? 1 : 0.82)
            }
            .foregroundColor(selected ? Palette.purple : Palette.subtle)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if selected {
                    selectionPill
                        .matchedGeometryEffect(id: "tab-pill", in: pillNS)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(SoftPressStyle(scale: 0.93, dim: 0.9))
    }

    /// 选中态的玻璃小胶囊：比外层更亮一点，像一枚凸起的透镜
    private var selectionPill: some View {
        let light = scheme == .light
        return Capsule()
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule().fill(
                    LinearGradient(
                        colors: light
                            ? [Color.white.opacity(0.98), Color.white.opacity(0.72)]
                            : [Palette.purple.opacity(0.34), Palette.purple.opacity(0.14)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            )
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: light
                            ? [Color.white, Color.white.opacity(0.35)]
                            : [Color.white.opacity(0.30), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: .black.opacity(light ? 0.10 : 0.35), radius: 7, x: 0, y: 3)
            .shadow(color: Palette.purple.opacity(light ? 0.16 : 0.28), radius: 10, x: 0, y: 2)
    }

    /// 斜掠高光
    private var sheen: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, .white.opacity(scheme == .light ? 0.55 : 0.22), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.42, height: geo.size.height * 1.6)
            .blur(radius: 10)
            .rotationEffect(.degrees(12))
            .offset(x: sweep * geo.size.width)
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }
}
