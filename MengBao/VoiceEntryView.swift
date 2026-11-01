import SwiftUI
import Network
import Speech
import AVFoundation

// MARK: - 语音录入（一键长录音版）

/// 打开即听：进来自动开始识别，想到什么说什么（喝奶、睡觉、尿布…混着说都行）；
/// 说完点一下麦克风结束，整段话自动拆成多条记录，逐条确认后一键保存。
/// 语音不可用（没权限 / 没识别包 / 没网）时，下面的文字输入走同一套解析。
struct VoiceEntryView: View {
    @EnvironmentObject private var store: Store
    @StateObject private var recorder = SpeechRecorder()

    let onClose: () -> Void

    @State private var granted = false
    @State private var sessionActive = true      // 是否继续自动续录
    @State private var mode = "listen"           // listen / review
    @State private var segments: [String] = []   // 已识别的每一段
    @State private var results: [VoiceParseResult] = []
    @State private var unknown: [String] = []
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
                        if let text = messageText {
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
            // 一键直达：进来就自动开始听
            recorder.requestPermission { ok in
                granted = ok
                if ok {
                    recorder.start()
                } else {
                    hint = "没有麦克风/语音识别权限，可以直接用下面的文字输入。"
                }
            }
        }
        .onDisappear {
            recorder.stop()
        }
        .onChange(of: recorder.segmentTick) { _ in
            // 一段识别收尾（isFinal / 服务超时均算）：存段，若还在会话里就自动续录
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
            Text("🎙️").font(.system(size: 20))
            Text(mode == "review" ? "确认记录 · \(results.count) 条" : "语音记一笔 · 长录音")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Palette.ink)
            Spacer()
            Button {
                recorder.stop()
                onClose()
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

    // MARK: 麦克风（聆听中）

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

            Text("喝奶、睡觉、尿布、辅食、身高体重…一口气全说完，说完点一下麦克风结束")
                .font(.system(size: 12))
                .foregroundColor(Palette.subtle)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            // 已识别内容（实时）
            if !recorder.transcript.isEmpty || !segments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(segments, id: \.self) { seg in
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

            Button {
                sessionActive = false
                mode = "listen"
                finalize()
            } label: {
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

    // MARK: 多条确认

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if results.isEmpty {
                Text("全部删掉了，点「重说」再来一遍")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.subtle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
            ForEach(results.indices, id: \.self) { i in
                let r = results[i]
                HStack(spacing: 10) {
                    Text(emoji(for: r))
                        .font(.system(size: 22))
                        .frame(width: 38, height: 38)
                        .background(Palette.purpleTint)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.summary)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundColor(Palette.ink)
                        if !r.note.isEmpty && r.kind != "solid" && r.kind != "supplement" {
                            Text(r.note)
                                .font(.system(size: 11))
                                .foregroundColor(Palette.subtle)
                        }
                    }
                    Spacer(minLength: 0)
                    Button {
                        results.remove(at: i)
                    } label: {
                        Text("✕")
                            .font(.system(size: 13))
                            .foregroundColor(Palette.subtle)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.purpleTint.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if !unknown.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("这几句没认出类型，没有记录：")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(Palette.warn)
                    ForEach(unknown, id: \.self) { u in
                        Text("· \(u)")
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.warn)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.warn.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 10) {
                Button {
                    startOver()
                } label: {
                    Text("重说")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.subtle)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                Button {
                    saveAll(results)
                } label: {
                    Text("保存 \(results.count) 条")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(results.isEmpty ? Palette.subtle.opacity(0.4) : Palette.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(results.isEmpty)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 文字兜底

    private var fallbackCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == "review" ? "还有要记的？继续打字" : "不方便说话？直接打字")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Palette.ink)
            Text("可以说一大段：「喝了150毫升奶，换了尿布，睡了1个半小时」")
                .font(.system(size: 11))
                .foregroundColor(Palette.subtle)
            HStack(spacing: 8) {
                TextField("例如：喝了 150 毫升奶，睡了 1 小时", text: $typed)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Palette.purpleTint)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button {
                    parseTyped()
                } label: {
                    Text("识别")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Palette.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Text("文字只在本机解析，不上传。")
                .font(.system(size: 11))
                .foregroundColor(Palette.subtle)
        }
        .cardStyle()
    }

    // MARK: 文案

    private var messageText: String? {
        if let hint = hint { return hint }
        return recorder.message
    }

    private func emoji(for r: VoiceParseResult) -> String {
        if r.kind == "growth" { return "📏" }
        guard let raw = r.kind, let kind = FeedLog.Kind(rawValue: raw) else { return "📝" }
        return kind.icon
    }

    // MARK: 交互

    /// 点麦克风 / 点「说完啦」：结束会话并结算
    private func stopSession() {
        sessionActive = false
        recorder.stop()
        finalize()
    }

    private func startOver() {
        segments = []
        results = []
        unknown = []
        typed = ""
        hint = nil
        sessionActive = true
        mode = "listen"
        recorder.start()
    }

    /// 整段拼起来 → parseAll → 确认页（或提示）
    private func finalize() {
        let all = (segments + [recorder.transcript]).joined().trimmed()
        segments = []
        if all.isEmpty {
            hint = "没听到内容，直接打字也可以。"
            return
        }
        let parsed = VoiceParser.parseAll(all)
        if parsed.results.isEmpty {
            hint = "这段话没认出能记录的内容：\n「\(all)」\n试试：喝了150毫升奶、睡了1小时20分钟、尿了、体温37.8"
            return
        }
        results = parsed.results
        unknown = parsed.unknown
        mode = "review"
    }

    private func parseTyped() {
        let text = typed.trimmed()
        guard !text.isEmpty else { return }
        recorder.stop()
        sessionActive = false
        hint = nil
        let parsed = VoiceParser.parseAll(text)
        if parsed.results.isEmpty {
            hint = "没认出能记录的内容，试试：喝了150毫升奶、睡了1小时、尿了、体温37.8"
            return
        }
        results = parsed.results
        unknown = parsed.unknown
        mode = "review"
    }

    private func startPulse() {
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }

    // MARK: 落库（多条）

    private func saveAll(_ list: [VoiceParseResult]) {
        guard store.current != nil else { return }
        for r in list {
            saveOne(r)
        }
        recorder.stop()
        onClose()
    }

    private func saveOne(_ r: VoiceParseResult) {
        guard let child = store.current else { return }
        let when = dateFor(r.hour)

        if r.kind == "growth", let unit = r.growthUnit, let v = r.value {
            let existing = child.records.first { Calendar.current.isDate($0.date, inSameDayAs: when) }
            var record = existing ?? GrowthRecord(date: when)
            if unit.0 == "身高" {
                record.height = v
            } else if unit.0 == "体重" {
                record.weight = v
            } else {
                record.headCirc = v
            }
            if existing != nil {
                store.updateRecord(record)
            } else {
                store.addRecord(record)
            }
        } else {
            let kind = r.kind.flatMap { FeedLog.Kind(rawValue: $0) } ?? .custom
            var log = FeedLog(date: when, kind: kind)
            log.minutes = r.minutes
            log.ml = r.ml
            log.side = r.side
            log.diaperKind = r.diaperKind
            log.value = r.value
            log.note = r.note
            store.addFeed(log)
        }
    }

    /// 句子里说了「下午三点」就用今天那个点，没说就用现在
    private func dateFor(_ hour: Int?) -> Date {
        guard let hour = hour else { return Date() }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = 0
        return cal.date(from: comps) ?? Date()
    }
}

// MARK: - 录音 + 转写

// MARK: - 语音识别模式（网络优先，可自动可手动）

enum SpeechMode: String, CaseIterable, Identifiable {
    case auto, online, offline
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: return "自动（推荐）"
        case .online: return "网络识别"
        case .offline: return "离线识别"
        }
    }
    var note: String {
        switch self {
        case .auto: return "有网用网络识别更准，没网自动切离线"
        case .online: return "只走网络，最准，但必须联网"
        case .offline: return "只在本机识别，不联网、不耗流量"
        }
    }
    static func from(_ raw: String) -> SpeechMode { SpeechMode(rawValue: raw) ?? .auto }
}

/// 轻量网络状态（NWPathMonitor 常驻，缓存当前是否有网）
final class Reachability {
    static let shared = Reachability()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "mengbao.reach")
    private(set) var isOnline = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isOnline = (path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }
}

final class SpeechRecorder: ObservableObject {
    @Published private(set) var transcript = ""      // 当前段的实时转写
    @Published private(set) var isRecording = false
    @Published private(set) var finishedSegment = "" // 刚收尾的一段（供视图层收集）
    @Published private(set) var segmentTick = 0      // 收尾次数计数（含空段，驱动自动续录）
    @Published private(set) var message: String? = nil

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false

    // MARK: 权限

    func requestPermission(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            // iOS 17 才有 AVAudioApplication.requestRecordPermission，这里用老的会话接口
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    // MARK: 开始

    /// 当前这次录音实际用的模式（自动模式下会随网络状态变化）
    @Published private(set) var usedOffline = false
    private var startedMode: SpeechMode = .auto

    func start(mode: SpeechMode = .auto) {
        startedMode = mode
        guard let recognizer = recognizer else {
            message = "这台设备不支持中文语音识别，试试下面的文字输入。"
            return
        }
        guard recognizer.isAvailable else {
            message = "语音识别暂时不可用（可能没网），试试下面的文字输入。"
            return
        }
        stop()
        transcript = ""
        finishedSegment = ""
        message = nil

        let session = AVAudioSession.sharedInstance()
        guard session.isInputAvailable else {
            message = "没有检测到麦克风，试试下面的文字输入。"
            return
        }
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            message = "麦克风启动失败，试试下面的文字输入。"
            return
        }

        let wantOffline: Bool
        switch mode {
        case .offline: wantOffline = true
        case .online: wantOffline = false
        case .auto: wantOffline = !Reachability.shared.isOnline
        }
        if wantOffline && !recognizer.supportsOnDeviceRecognition {
            message = "这台设备不支持离线识别，连上网络后再试"
            return
        }
        usedOffline = wantOffline

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        // 默认走网络（更准）；离线模式或没网时强制在设备端
        req.requiresOnDeviceRecognition = wantOffline
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            message = "麦克风不可用，试试下面的文字输入。"
            return
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        tapInstalled = true

        engine.prepare()
        do {
            try engine.start()
        } catch {
            stop()
            message = "麦克风启动失败，试试下面的文字输入。"
            return
        }
        isRecording = true

        task = recognizer.recognitionTask(with: req) { [weak self] res, error in
            guard let self = self else { return }
            if let res = res {
                let text = res.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcript = text
                    if res.isFinal {
                        self.isRecording = false
                        self.finishedSegment = text
                        self.segmentTick += 1
                    }
                }
            }
            if error != nil {
                DispatchQueue.main.async {
                    self.isRecording = false
                    // 自动模式下在线识别失败（没网 / 服务不可用）：立刻用离线重来一次
                    if self.startedMode == .auto, !self.usedOffline, recognizer.supportsOnDeviceRecognition {
                        self.stop()
                        self.usedOffline = true
                        self.message = "网络不太行，已切到离线识别"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            self.start(mode: .offline)
                        }
                        return
                    }
                    // 服务端约 1 分钟会掐断一次：把已识别的存为一段，视图层会自动续录
                    self.finishedSegment = self.transcript
                    self.segmentTick += 1
                }
            }
        }
    }

    // MARK: 停止

    func stop() {
        if engine.isRunning {
            engine.stop()
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
