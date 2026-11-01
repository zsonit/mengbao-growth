import SwiftUI

// MARK: - AI 语音助手
//
// 说一句话 → 大模型理解 → 直接记进 App（喂养/待办/身高体重/尺码），也能回答育儿问题。
// 用的云服务免密钥通道，家长不用配置任何 Key。

struct VoiceAssistantView: View {
    @EnvironmentObject private var store: Store
    @StateObject private var voice = SpeechRecorder()
    /// 打开某个页面（由外层 NavigationStack 提供）
    var onOpenPage: ((String) -> Void)? = nil

    @State private var turns: [Turn] = []
    @State private var typed = ""
    @State private var busy = false
    @State private var listening = false
    @State private var micHint: String?
    @State private var showModels = false
    @State private var models: [AIModel] = []
    @State private var modelError: String?
    @State private var silenceWork: DispatchWorkItem?
    @AppStorage("ai_model") private var model = "glm-5.3-flash"

    private let suggestions = ["宝宝刚喝了 120 的奶", "换了尿布，大便", "明天记得买纸尿裤", "今天睡了多久？"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Palette.hairlineSoft)
            conversation
            inputBar
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("AI 语音助手")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showModels) { modelSheet }
        .onChange(of: voice.transcript) { text in
            guard listening else { return }
            scheduleAutoSend(text)
        }
        .onChange(of: voice.isRecording) { rec in
            if !rec, listening, !voice.transcript.isEmpty {
                // 系统判定说完了：直接发
                finishAndSend()
            }
        }
    }

    // MARK: 顶部

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                loadModels()
                showModels = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles").font(.system(size: 11))
                    Text(modelLabel).font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.down").font(.system(size: 8))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Palette.purpleTint)
                .foregroundColor(Palette.purple)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("免费模型 · 无需配置")
                .font(.system(size: 11))
                .foregroundColor(Palette.subtle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private var modelLabel: String {
        if let m = models.first(where: { $0.id == model }) { return m.label }
        if model == "auto" { return "自动" }
        return model
    }

    // MARK: 对话区

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if turns.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(turns) { t in
                            turnView(t).id(t.id)
                        }
                        if busy {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.7)
                                Text("正在理解…").font(.system(size: 12.5)).foregroundColor(Palette.subtle)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .id("busy")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .onChange(of: turns.count) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(busy ? "busy" : turns.last?.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Palette.purpleTint).frame(width: 86, height: 86)
                Text("🎙️").font(.system(size: 34))
            }
            VStack(spacing: 6) {
                Text("说一句话就能记下来").font(.system(size: 15, weight: .semibold)).foregroundColor(Palette.ink)
                Text("比如「宝宝十点喝了 120 的奶」「明天买纸尿裤」\n也可以直接问「今天睡了多久」")
                    .font(.system(size: 12.5))
                    .foregroundColor(Palette.subtle)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        send(s)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "quote.opening").font(.system(size: 9))
                            Text(s).font(.system(size: 13))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Palette.card)
                        .foregroundColor(Palette.ink2)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.hairlineSoft))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
    }

    private func turnView(_ t: Turn) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            // 家长说的
            HStack {
                Spacer(minLength: 40)
                Text(t.ask)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(Palette.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // 助手回的
            VStack(alignment: .leading, spacing: 9) {
                if t.streaming {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.65)
                        Text("正在理解…").font(.system(size: 13)).foregroundColor(Palette.subtle)
                    }
                } else if let e = t.error {
                    HStack(alignment: .top, spacing: 6) {
                        Text("⚠️").font(.system(size: 13))
                        Text(e).font(.system(size: 13)).foregroundColor(Palette.ink2)
                    }
                } else {
                    Text(t.reply)
                        .font(.system(size: 14))
                        .foregroundColor(Palette.ink)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 已执行的动作
                if !t.items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(t.items) { item in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Palette.ok)
                                Text(item.label)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Palette.ink2)
                                Spacer(minLength: 0)
                            }
                        }
                        Button {
                            for item in t.items { item.undo() }
                            if let idx = turns.firstIndex(where: { $0.id == t.id }) {
                                turns[idx].items = []
                                turns[idx].reply = "已经撤销刚才的记录了。"
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward").font(.system(size: 10))
                                Text("撤销").font(.system(size: 12))
                            }
                            .foregroundColor(Palette.bad)
                            .padding(.top, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }

                // 动作里带了「打开某页」
                if let p = t.page, let open = onOpenPage {
                    Button {
                        open(p)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square").font(.system(size: 11))
                            Text("打开\(AIAssistant.pages.first(where: { $0.key == p })?.name ?? "页面")")
                                .font(.system(size: 12.5, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 9))
                        }
                        .foregroundColor(Palette.purple)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(Palette.purpleTint)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairlineSoft))
        }
    }

    // MARK: 底部输入

    private var inputBar: some View {
        VStack(spacing: 8) {
            if listening {
                HStack(spacing: 8) {
                    Circle().fill(Palette.bad).frame(width: 7, height: 7)
                    Text(voice.transcript.isEmpty ? "我在听…" : voice.transcript)
                        .font(.system(size: 13))
                        .foregroundColor(Palette.ink2)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            if let m = micHint ?? voice.message, listening || micHint != nil {
                Text(m).font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 10) {
                Button {
                    toggleListen()
                } label: {
                    ZStack {
                        if listening {
                            Circle().fill(Palette.bad.opacity(0.15)).frame(width: 52, height: 52)
                        }
                        Circle()
                            .fill(listening ? Palette.bad : Palette.purple)
                            .frame(width: 40, height: 40)
                        Image(systemName: listening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .disabled(busy)

                HStack(spacing: 6) {
                    TextField("也可以打字，比如：晚上八点体温 38 度", text: $typed)
                        .font(.system(size: 13.5))
                        .submitLabel(.send)
                        .onSubmit { submitTyped() }
                    if !typed.isEmpty {
                        Button { submitTyped() } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Palette.purple)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Palette.card)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Palette.hairlineSoft))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            Text("由云端免费模型理解，仅供记录辅助；医疗问题请及时就医")
                .font(.system(size: 10))
                .foregroundColor(Palette.subtle.opacity(0.8))
                .padding(.bottom, 6)
        }
        .padding(.top, 8)
        .background(Palette.background)
    }

    // MARK: 逻辑

    private func toggleListen() {
        if listening {
            finishAndSend()
            return
        }
        voice.requestPermission { ok in
            guard ok else {
                micHint = "没有麦克风权限，用下面的输入框打字也一样"
                return
            }
            listening = true
            voice.start()
        }
    }

    private func scheduleAutoSend(_ text: String) {
        silenceWork?.cancel()
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let work = DispatchWorkItem { [text] in
            guard listening else { return }
            finishAndSend(forceText: text)
        }
        silenceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private func finishAndSend(forceText: String? = nil) {
        silenceWork?.cancel()
        silenceWork = nil
        let text = (forceText ?? voice.transcript).trimmingCharacters(in: .whitespacesAndNewlines)
        voice.stop()
        listening = false
        guard !text.isEmpty else { return }
        send(text)
    }

    private func submitTyped() {
        let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        typed = ""
        send(text)
    }

    private func send(_ text: String) {
        guard !busy else { return }
        busy = true
        let turn = Turn(ask: text, streaming: true)
        turns.append(turn)

        Task {
            do {
                let plan = try await AIAssistant.interpret(
                    text: text,
                    child: store.current,
                    store: store,
                    model: model
                )
                await MainActor.run {
                    if let idx = turns.firstIndex(where: { $0.id == turn.id }) {
                        turns[idx].reply = plan.reply
                        turns[idx].items = plan.items
                        turns[idx].page = plan.openPage
                        turns[idx].streaming = false
                    }
                    busy = false
                }
            } catch {
                await MainActor.run {
                    if let idx = turns.firstIndex(where: { $0.id == turn.id }) {
                        turns[idx].error = (error as? AIError)?.errorDescription ?? error.localizedDescription
                        turns[idx].streaming = false
                    }
                    busy = false
                }
            }
        }
    }

    // MARK: 模型选择

    private func loadModels() {
        guard models.isEmpty else { return }
        Task {
            do {
                let list = try await AIClient.shared.models()
                await MainActor.run {
                    models = list
                    modelError = nil
                }
            } catch {
                await MainActor.run {
                    modelError = (error as? AIError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private var modelSheet: some View {
        NavigationStack {
            List {
                Section {
                    if let e = modelError {
                        Text(e).font(.system(size: 12.5)).foregroundColor(Palette.subtle)
                    } else if models.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.7)
                            Text("正在获取…").font(.system(size: 13)).foregroundColor(Palette.subtle)
                        }
                    }
                    ForEach(Array(AIModel.quick(models).enumerated()), id: \.offset) { idx, m in
                        Button {
                            model = m.id
                            showModels = false
                        } label: {
                            row(
                                title: idx == 0 ? m.label + "（推荐）" : m.label,
                                sub: idx == 0 ? "速度快，2～3 秒出结果" : m.id,
                                on: model == m.id
                            )
                        }
                    }
                    Button {
                        model = "auto"
                        showModels = false
                    } label: {
                        row(title: "自动", sub: "按任务自动挑模型，问答更聪明但慢一些", on: model == "auto")
                    }
                } footer: {
                    Text("语音记录用「推荐」的快速模型就够；问复杂问题时可以切「自动」。")
                }
            }
            .navigationTitle("选择模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showModels = false }
                }
            }
            .onAppear { loadModels() }
        }
        .presentationDetents([.medium])
    }

    private func row(title: String, sub: String, on: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: on ? .semibold : .regular)).foregroundColor(Palette.ink)
                Text(sub).font(.system(size: 11)).foregroundColor(Palette.subtle)
            }
            Spacer()
            if on {
                Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold)).foregroundColor(Palette.purple)
            }
        }
    }

    // MARK: 一轮对话

    struct Turn: Identifiable {
        let id = UUID()
        let ask: String
        var reply: String = ""
        var streaming: Bool = false
        var items: [AIActionItem] = []
        var error: String?
        var page: String?
    }
}
