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
    @State private var fingerDown = false    // 手指是否还按着（权限回调是异步的，必须用它防“点一下卡死”）
    @State private var holdStart = Date()
    @AppStorage("ai_model") private var model = "glm-5.3-flash"

    /// AI 要求打开某个页面时回调（home/feed/trends/history/todo/vaccine/size/growth/teeth/profile）
    var onOpenPage: (String) -> Void

    var body: some View {
        // 只保留悬浮麦克风按钮。
        // 全屏遮罩不在这里画——本按钮挂在首页 ScrollView 的 .overlay 上，还被
        // .padding(.bottom, 112) 顶到玻璃栏上方，所以它自身的 bounds 底部就是缺的，
        // 在里面 ignoresSafeArea 也铺不满（2.9.6/2.9.7 的底部缺口就是这么来的）。
        // 遮罩改由 RootView 顶层渲染，见 VoiceHoldOverlay。
        Button {} label: { fabLabel }
            .buttonStyle(.plain)
            .simultaneousGesture(holdGesture)
            .disabled(processing)
            // 按住录音时只把它变透明（不移除视图，否则手势会被打断、录音停不掉），
            // 避免它和遮罩里的大圆钮叠成两个图案
            .opacity(holding || processing ? 0 : 1)
            .sheet(item: $plan) { p in
                HoldResultSheet(plan: p, onOpenPage: onOpenPage)
                    .presentationDetents([.medium, .large])
            }
            // 录音 / 理解期间把状态上报给全局：玻璃栏收起 + 顶层遮罩出现
            .onChange(of: holding) { h in
                store.voiceHolding = h
                store.voiceActive = h || processing
            }
            .onChange(of: processing) { p in
                store.voiceProcessing = p
                store.voiceActive = holding || p
            }
            .onChange(of: voice.transcript) { t in
                store.voiceLiveText = t
            }
            // 遮罩被点一下（逃生口）：等同松手
            .onChange(of: store.voiceStopTick) { _ in
                if holding { endHold() }
            }
            .onDisappear {
                store.voiceActive = false
                store.voiceHolding = false
                store.voiceProcessing = false
                store.voiceLiveText = ""
                if holding { voice.stop(); holding = false }
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
                // onChanged 会连发多次，只在第一下真正开始
                guard !fingerDown else { return }
                fingerDown = true
                beginHold()
            }
            .onEnded { _ in
                fingerDown = false
                endHold()
            }
    }

    private func beginHold() {
        guard !holding, !processing else { return }
        guard store.current != nil else {
            errorText = "先在右上角建一个宝宝档案"
            plan = AIPlan.error(errorText ?? "")
            return
        }
        holdStart = Date()
        voice.requestPermission { ok in
            guard ok else {
                plan = AIPlan.error("没有麦克风权限，去 设置 → 隐私与安全性 → 麦克风 里打开")
                return
            }
            // 关键：权限回调是异步的。如果手指已经抬起（用户只是点了一下），
            // 绝不能启动录音——否则 onEnded 早已走过，没人再来 stop()，就永远卡在「我在听…」
            guard fingerDown else { return }
            voice.start()
            if let m = voice.message {
                // 启动失败（没网 / 没麦克风 / 不支持）：不进入录音态，直接给出原因
                plan = AIPlan.error(m)
                return
            }
            withAnimation(Anim.pop) { holding = true }
        }
    }

    private func endHold() {
        guard holding else { return }
        // 快速点按（<0.35s）当误触：直接取消，不进 AI，也不弹「没听清」
        if Date().timeIntervalSince(holdStart) < 0.35 {
            cancelHold()
            return
        }
        withAnimation(Anim.pop) { holding = false }
        voice.stop()
        finish(text: voice.transcript)
    }

    private func cancelHold() {
        voice.stop()
        withAnimation(Anim.pop) { holding = false }
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

}

// MARK: - 全屏遮罩（由 RootView 顶层渲染，才能真正铺满整块屏幕）

struct VoiceHoldOverlay: View {
    /// 松手后正在理解
    let processing: Bool
    /// 实时转写文本
    let said: String
    /// 点一下遮罩（逃生口）
    var onTap: () -> Void

    var body: some View {
        ZStack {
            // 玻璃底：不裁剪、不跟随任何 padding，四边一直铺到屏幕边缘
            Rectangle().fill(.ultraThinMaterial)

            VStack(spacing: 26) {
                Spacer()

                if processing {
                    VStack(spacing: 16) {
                        ProgressView().tint(Palette.purple)
                        Text("正在理解…").font(.system(size: 15, weight: .medium)).foregroundColor(Palette.ink)
                        Text(said).font(.system(size: 13)).foregroundColor(Palette.subtle)
                            .multilineTextAlignment(.center).padding(.horizontal, 40)
                    }
                } else {
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

                    if said.isEmpty {
                        Text("我在听…").font(.system(size: 16, weight: .medium)).foregroundColor(Palette.ink)
                    } else {
                        Text(said)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Palette.ink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                            .lineLimit(4)
                    }
                }

                Spacer()

                Text(processing ? "" : "松手结束 · 网络识别")
                    .font(.system(size: 12.5))
                    .foregroundColor(Palette.subtle)
                    .padding(.bottom, 28)
            }
        }
        // 关键：铺到状态栏与 Home 指示条之外，底部不再留缺口
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
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
                .buttonStyle(SoftPressStyle())
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
                    .buttonStyle(SoftPressStyle())
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
                .buttonStyle(SoftPressStyle())
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
