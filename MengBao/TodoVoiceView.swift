import SwiftUI

// MARK: - 用说话的方式加待办

/// 打开即听：「明天打疫苗，后天买维生素 D3，周五去体检」一口气说完，
/// 自动拆成 3 条待办，并认出「明天 / 后天 / 周五」作为截止日期；
/// 确认页可以改文字、删条目，再一次性加入待办清单。
struct TodoVoiceView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    /// 保存成功回调（条数），外层负责收起编辑页 / 提示
    var onSaved: (Int) -> Void

    @StateObject private var recorder = SpeechRecorder()

    @State private var granted = false
    @State private var sessionActive = true
    @State private var mode = "listen"        // listen / review
    @State private var segments: [String] = []
    @State private var drafts: [TodoDraft] = []
    @State private var typed = ""
    @State private var hint: String? = nil
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Palette.hairline)
                .frame(width: 38, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 10)

            header

            ScrollView {
                VStack(spacing: 14) {
                    if mode == "review" {
                        reviewSection
                    } else {
                        micSection
                        if let text = hint {
                            Text(text)
                                .font(.system(size: 12.5))
                                .foregroundColor(Palette.warn)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 8)
                        }
                    }
                    fallbackCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 26)
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            startPulse()
            recorder.requestPermission { ok in
                granted = ok
                if ok {
                    recorder.start()
                } else {
                    hint = "没有麦克风/语音识别权限，可以直接用下面的文字输入。"
                }
            }
        }
        .onDisappear { recorder.stop() }
        .onChange(of: recorder.segmentTick) { _ in
            guard mode == "listen", sessionActive, granted else { return }
            if !recorder.finishedSegment.isEmpty {
                segments.append(recorder.finishedSegment)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if sessionActive, mode == "listen" { recorder.start() }
            }
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(spacing: 8) {
            Text("📋").font(.system(size: 20))
            Text(mode == "review" ? "确认待办 · \(drafts.count) 条" : "语音加待办")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Palette.ink)
            Spacer()
            Button {
                recorder.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Palette.subtle.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    // MARK: 聆听中

    private var micSection: some View {
        VStack(spacing: 12) {
            Button { stopSession() } label: {
                ZStack {
                    Circle()
                        .stroke(Palette.purple.opacity(0.3), lineWidth: 2)
                        .frame(width: 104, height: 104)
                        .scaleEffect(pulse ? 1.35 : 1)
                        .opacity(recorder.isRecording ? (pulse ? 0 : 0.9) : 0)

                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: 0xFF8FB1), Color(hex: 0xA97BFF)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 104, height: 104)
                        .shadow(color: Color(hex: 0xFF8FB1).opacity(0.35), radius: 14, y: 6)

                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 84, height: 84)

                    Image(systemName: recorder.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)

            Text(recorder.isRecording ? "正在听… 想到什么说什么" : "正在准备麦克风…")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(Palette.ink2)

            Text("可以连着说好几件事：「明天打疫苗，后天买维生素 D3，周五去体检」\n日期会一起认出来")
                .font(.system(size: 12))
                .foregroundColor(Palette.subtle)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            if !recorder.transcript.isEmpty || !segments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                        Text("· \(seg)")
                            .font(.system(size: 13.5))
                            .foregroundColor(Palette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !recorder.transcript.isEmpty {
                        Text("· \(recorder.transcript) …")
                            .font(.system(size: 13.5))
                            .foregroundColor(Palette.purple)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.purpleTint)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button { stopSession() } label: {
                Text("说完啦 ✓")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Palette.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    // MARK: 确认

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if drafts.isEmpty {
                Text("没听出可以记的待办，点下面的文字框直接写，或者关掉重新说一遍。")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.subtle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .multilineTextAlignment(.center)
            }

            ForEach($drafts) { $draft in
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        TextField("要做的事", text: $draft.title)
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundColor(Palette.ink)
                        if let due = draft.due {
                            Button {
                                draft.due = nil
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "calendar").font(.system(size: 10))
                                    Text(dueText(due)).font(.system(size: 11.5, weight: .semibold))
                                    Image(systemName: "xmark").font(.system(size: 8))
                                }
                                .foregroundColor(Palette.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Palette.purpleTint)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer(minLength: 6)
                    Button {
                        drafts.removeAll { $0.id == draft.id }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Palette.subtle)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 10) {
                Button {
                    startOver()
                } label: {
                    Text("重说")
                        .font(.system(size: 14))
                        .foregroundColor(Palette.subtle)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Palette.purpleTint)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    save()
                } label: {
                    Text("加入待办清单（\(drafts.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }.count)）")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Palette.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(drafts.isEmpty)
                .opacity(drafts.isEmpty ? 0.5 : 1)
            }
            .padding(.top, 4)
        }
    }

    // MARK: 打字兜底

    private var fallbackCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("不方便说话？直接打字，也一样能拆成多条")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Palette.ink)
            Text("用逗号隔开：「明天打疫苗，后天买维生素 D3」")
                .font(.system(size: 11))
                .foregroundColor(Palette.subtle)
            HStack(spacing: 8) {
                TextField("例如：周五去体检，记得带疫苗本", text: $typed)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Palette.purpleTint)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button {
                    parseTyped()
                } label: {
                    Text("拆开")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Palette.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(13)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    // MARK: 逻辑

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
    }

    private func stopSession() {
        sessionActive = false
        recorder.stop()
        finalize()
    }

    private func finalize() {
        let all = (segments + [recorder.transcript]).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        segments = []
        guard !all.isEmpty else {
            hint = "没听到内容，直接打字也可以。"
            return
        }
        let parsed = TodoParser.parse(all)
        guard !parsed.isEmpty else {
            hint = "这句话没听出待办：\n「\(all)」\n试试：明天打疫苗、周五去体检"
            return
        }
        drafts = parsed
        hint = nil
        mode = "review"
    }

    private func parseTyped() {
        let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        recorder.stop()
        sessionActive = false
        let parsed = TodoParser.parse(text + (mode == "review" ? "" : "，"))
        if !parsed.isEmpty {
            drafts.append(contentsOf: parsed)
            typed = ""
            hint = nil
            mode = "review"
        } else {
            hint = "没认出待办内容，换个说法试试。"
        }
    }

    private func startOver() {
        drafts = []
        segments = []
        typed = ""
        hint = nil
        sessionActive = true
        mode = "listen"
        recorder.start()
    }

    private func save() {
        let items = drafts
            .map { TodoItem(title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines), due: $0.due) }
            .filter { !$0.title.isEmpty }
        guard !items.isEmpty else { return }
        store.addTodos(items)
        recorder.stop()
        onSaved(items.count)
        dismiss()
    }

    private func dueText(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "今天"
        case 1: return "明天"
        case 2: return "后天"
        case 3: return "大后天"
        default:
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "M月d日"
            return f.string(from: date)
        }
    }
}
