import SwiftUI

// MARK: - 液态玻璃（Liquid Glass）材质
//
// 参照 iOS 26 液态玻璃观感：半透明材质 + 顶部受光的高光渐变 + 亮边内描边 + 柔和投影。
// 有意不调用 `.glassEffect()`（那是 iOS 26 SDK 才有的符号，CI 的 Xcode 版本不受控），
// 用系统 `.ultraThinMaterial` 手工叠出来，iOS 16 起全部可用，新旧系统观感一致。

extension View {
    /// 给任意内容包一层液态玻璃背景
    /// - Parameters:
    ///   - shape: 玻璃的形状（胶囊 / 圆角矩形都行）
    ///   - intensity: 白色高光强度，0～1；底色越深给得越大
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
        // 亮色下玻璃偏白受光；暗色下高光收敛，保持「黑玻璃」质感
        let hiTop = (light ? 0.55 : 0.16) * intensity
        let hiBottom = (light ? 0.16 : 0.04) * intensity
        let edgeTop = (light ? 0.90 : 0.28) * intensity
        let edgeBottom = (light ? 0.20 : 0.10) * intensity

        return content
            .background(
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    // 顶光：上亮下透的白渐变
                    LinearGradient(
                        colors: [.white.opacity(hiTop), .white.opacity(hiBottom)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .clipShape(shape)
                    // 内描边：上缘亮、下缘暗，玻璃边缘的受光感
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(edgeTop), .white.opacity(edgeBottom)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
            )
            .shadow(color: .black.opacity(light ? 0.10 : 0.30), radius: 14, x: 0, y: 5)
    }
}

// MARK: - 悬浮液态玻璃 Tab 栏

struct LiquidTabBar: View {
    struct Item: Identifiable {
        let id: String
        let label: String
        let icon: String
    }

    let items: [Item]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let selected = item.id == selection
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        selection = item.id
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 19, weight: selected ? .semibold : .regular))
                            .symbolRenderingMode(.hierarchical)
                        Text(item.label)
                            .font(.system(size: 10.5, weight: selected ? .semibold : .regular))
                    }
                    .foregroundColor(selected ? Palette.purple : Palette.subtle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if selected {
                            // 选中项：白色胶囊浮起（录屏同款）
                            Capsule()
                                .fill(Color.white.opacity(0.92))
                                .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
                                .overlay(
                                    Capsule().strokeBorder(.white.opacity(0.9), lineWidth: 0.8)
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .liquidGlass(in: Capsule())
        .padding(.horizontal, 24)
        .padding(.bottom, 2)
    }
}
