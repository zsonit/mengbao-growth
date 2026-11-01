import SwiftUI
import AVFoundation

// MARK: - 按住说话（Hold-to-Talk）
//
// 参照录屏交互：主页悬浮麦克风 → 按住不动原地录音（不跳页）→ 松手结束
// → 大模型理解并执行 → 底部弹出结果面板（可撤销、可跳页）。

struct HoldToTalkButton: View {
    @EnvironmentObject private var store: Store
    @StateObject private var voice = SpeechRecorder()

    @State private var holding = false       // 正在按住录音
    @State private var processing = false    // 松手后 AI 正在理解
    @State private var plan: AIPlan?         // 理解结果（弹面板）
    @State private var errorText: String?
    @AppStorage("ai_model") private var model = "glm-5.3-flash"

    /// AI 要求打开某个页面时回调（home/feed/trends/history/todo/vaccine/size/growth/teeth/profile）
    var onOpenPage: (String) -> Void

    var body: some View {
        ZStack {
            // 按住时的全屏玻璃面板
            if holding || processing {
                holdOverlay.transition(.opacity)
            }

            // 悬浮麦克风按钮
            Button {} label: { fabLabel }
                .buttonStyle(.plain)
                .simultaneousGesture(holdGesture)
                .disabled(processing)
        }
        .sheet(item: $plan) { p in
            HoldResultSheet(plan: p, onOpenPage: onOpenPage)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: 按钮

    private var fabLabel: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xFF8FB1), Color(hex: 0xA97BFF)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 58, height: 58)
                .shadow(color: Color(hex: 0xA97BFF).opacity(0.45), radius: 12, y: 6)
            Image(systemName: holding ? "waveform" : "mic.fill")
                .font(.system(size: 23, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    // MARK: 按住手势

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !holding, !processing else { return }
                guard store.current != nil else {
                    errorText = "先在右上角建一个宝宝档案"
                    plan = AIPlan.error(errorText ?? "")
                    return
                }
                voice.requestPermission { ok in
                    guard ok else {
                        plan = AIPlan.error("没有麦克风权限，去 设置 → 隐私与安全性 → 麦克风 里打开")
                        return
                    }
                    voice.start()
                    withAnimation(.easeOut(duration: 0.18)) { holding = true }
                }
            }
            .onEnded { _ in
                guard holding else { return }
                withAnimation(.easeIn(duration: 0.15)) { holding = false }
                voice.stop()
                finish(text: voice.transcript)
            }
    }

    // MARK: 松手后交给 AI

    private func finish(text: String) {
        let said = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard said.count >= 2 else {
            plan = AIPlan.error("没听清说什么，按住再说一次")
            return
        }
        processing = true
        Task {
            defer { processing = false }
            do {
                let p = try await AIAssistant.interpret(text: said, child: store.current, store: store, model: model)
                plan = p
            } catch {
                let m = (error as? LocalizedError)?.errorDescription ?? "没连上模型，稍后再试一次"
                plan = AIPlan.error(m)
            }
        }
    }

    // MARK: 按住时的遮罩

    private var holdOverlay: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                if processing {
                    // 松手后：正在理解
                    VStack(spacing: 16) {
                        ProgressView().tint(Palette.purple)
                        Text("正在理解…").font(.system(size: 15, weight: .medium)).foregroundColor(Palette.ink)
                        Text(saidText).font(.system(size: 13)).foregroundColor(Palette.subtle)
                            .multilineTextAlignment(.center).padding(.horizontal, 40)
                    }
                } else {
                    // 按住中：波纹 + 大圆钮 + 实时转写
                    ZStack {
                        RippleView(color: Palette.purple)
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: 0xFF8FB1), Color(hex: 0xA97BFF)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 96, height: 96)
                            .shadow(color: Color(hex: 0xA97BFF).opacity(0.5), radius: 20, y: 8)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    if saidText.isEmpty {
                        Text("我在听…").font(.system(size: 16, weight: .medium)).foregroundColor(Palette.ink)
                    } else {
                        Text(saidText)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Palette.ink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                            .lineLimit(4)
                    }
                }

                Spacer()

                Text(processing ? "" : "松手结束")
                    .font(.system(size: 12.5))
                    .foregroundColor(Palette.subtle)
                    .padding(.bottom, 28)
            }
        }
    }

    private var saidText: String {
        voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 波纹

private struct RippleView: View {
    @State private var animate = false
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(0.45), lineWidth: 2)
                    .frame(width: 96, height: 96)
                    .scaleEffect(animate ? 2.3 : 1.0)
                    .opacity(animate ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 1.8)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.6),
                        value: animate
                    )
                }
        }
        .onAppear { animate = true }
    }
}

// MARK: - 结果面板（松手后弹出）

private struct HoldResultSheet: View {
    let plan: AIPlan
    var onOpenPage: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule().fill(Palette.hairline).frame(width: 36, height: 5)
                .frame(maxWidth: .infinity).padding(.top, 8)

            HStack(spacing: 10) {
                Image(systemName: plan.items.isEmpty ? "text.bubble" : "checkmark.circle.fill")
                    .foregroundColor(plan.items.isEmpty ? Palette.subtle : Palette.ok)
                Text(plan.reply.isEmpty ? (plan.items.isEmpty ? plan.errorNote : "记好了") : plan.reply)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Palette.ink)
            }

            if !plan.items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(plan.items) { item in
                        HStack(spacing: 10) {
                            Circle().fill(Palette.purple.opacity(0.15)).frame(width: 8, height: 8)
                            Text(item.label).font(.system(size: 14)).foregroundColor(Palette.ink2)
                            Spacer()
                        }
                    }
                }
                .padding(14)
                .background(Palette.purpleTint)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let page = plan.openPage, let name = AIAssistant.pages.first(where: { $0.key == page })?.name {
                Button {
                    dismiss()
                    onOpenPage(page)
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("去 \(name)").font(.system(size: 14, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11))
                    }
                    .foregroundColor(Palette.purple)
                    .padding(13)
                    .background(Palette.purpleTint)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HStack(spacing: 12) {
                if !plan.items.isEmpty {
                    Button {
                        plan.items.forEach { $0.undo() }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.backward")
                            Text("撤销")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Palette.hairlineSoft)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    dismiss()
                } label: {
                    Text(plan.items.isEmpty ? "知道了" : "完成")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Palette.purple)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
}

// MARK: - 辅助

extension AIPlan: Identifiable {
    var id: String { reply + "\(items.count)" + (openPage ?? "") }

    /// 错误提示也用结果面板展示
    static func error(_ text: String) -> AIPlan {
        AIPlan(reply: text, items: [], openPage: nil)
    }

    var errorNote: String { reply }
}
