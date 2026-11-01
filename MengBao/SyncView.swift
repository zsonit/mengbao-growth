import SwiftUI

// MARK: - 配对同步

/// 一台手机创建配对码，另一台输入同一个码，之后双方联网就自动双向同步全部资料。
struct SyncView: View {
    @ObservedObject private var sync = SyncManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var joinText = ""
    @State private var running = false
    @State private var toast: String?

    private var code: String? { sync.pairedCode }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let code {
                        pairedSection(code)
                    } else {
                        howToCard
                        createCard
                        joinCard
                    }
                    notesCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("☁️ 配对同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .padding(.bottom, 40)
                    .transition(.opacity)
            }
        }
    }

    // MARK: 未配对

    private var howToCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("怎么用").font(.system(size: 13, weight: .bold)).foregroundColor(Palette.ink)
                Text("① 这台手机点「创建配对码」\n② 家人手机输入同一个码\n③ 之后所有手机联网就自动同步全部资料\n（爷爷奶奶、外公外婆的手机都可以加，数量不限）")
                    .font(.system(size: 12.5))
                    .foregroundColor(Palette.ink2)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var createCard: some View {
        card {
            VStack(spacing: 10) {
                Button {
                    run { sync.createPairing() }
                } label: {
                    Text(running ? "正在创建…" : "创建配对码")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Palette.purple))
                }
                .buttonStyle(.plain)
                .disabled(running)
            }
        }
    }

    private var joinCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("已有配对码？").font(.system(size: 13, weight: .bold)).foregroundColor(Palette.ink)
                TextField("输入对方的 6 位配对码", text: $joinText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Palette.purpleTint)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button {
                    run { sync.joinPairing(joinText) }
                } label: {
                    Text(running ? "正在配对…" : "加入配对")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(joinText.isEmpty ? Palette.subtle.opacity(0.4) : Palette.purple))
                }
                .buttonStyle(.plain)
                .disabled(running || joinText.isEmpty)
            }
        }
    }

    // MARK: 已配对

    private func pairedSection(_ code: String) -> some View {
        VStack(spacing: 14) {
            card {
                VStack(spacing: 6) {
                    Text("配对码").font(.system(size: 12)).foregroundColor(Palette.subtle)
                    Text(code.chunked(3).joined(separator: " "))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Palette.purpleDeep)
                        .kerning(2)
                    Text("把这个码告诉家人，任何一台手机装好萌宝成长后在「我的 → 配对同步」输入即可加入，数量不限")
                        .font(.system(size: 11.5))
                        .foregroundColor(Palette.subtle)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity)
            }

            card {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("上次同步").font(.system(size: 12.5)).foregroundColor(Palette.ink2)
                            Text(lastSyncText)
                                .font(.system(size: 11.5))
                                .foregroundColor(Palette.subtle)
                        }
                        Spacer()
                        if sync.busy || running {
                            ProgressView().scaleEffect(0.8)
                        }
                    }
                    if let msg = sync.lastMessage {
                        Text(msg).font(.system(size: 11.5)).foregroundColor(Palette.subtle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button {
                        run { sync.syncNow(manual: true) }
                    } label: {
                        Text(sync.busy || running ? "同步中…" : "立即同步")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Palette.purple))
                    }
                    .buttonStyle(.plain)
                    .disabled(sync.busy || running)

                    Button {
                        run { sync.unlink() }
                    } label: {
                        Text("解除配对")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(Palette.warn)
                    }
                    .buttonStyle(.plain)
                    Text("解除后：本机和云端的资料都不会消失，只是不再同步；重新输入配对码可再次加入")
                        .font(.system(size: 10.5))
                        .foregroundColor(Palette.subtle)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var lastSyncText: String {
        guard sync.lastSyncAt > 0 else { return "还没同步过" }
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: Date(timeIntervalSince1970: sync.lastSyncAt))
    }

    private var notesCard: some View {
        card {
            Text("* 一个配对码可以加到多部手机（爸爸妈妈、爷爷奶奶都能加），大家看到的是同一份资料\n* 一台手机改了数据：2~3 秒内自动上传；其他手机开着 App 时约 12 秒内自动拉取，切回 App 会立刻同步\n* 同步内容：宝宝档案、喂养、生长、换牙、接种、尺码、待办\n* 各自新增的记录都会保留；同一处改动，后改的生效\n* 显示设置以本机为准\n* 解除配对只会停止同步：本机与云端的资料都保留\n* 端到端加密：资料在手机上用配对码加密后才上传，云端只存密文，服务器也读不到内容\n* 配对码就是唯一的钥匙，请只告诉家人")
                .font(.system(size: 11))
                .foregroundColor(Palette.subtle)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: 工具

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func run(_ block: @escaping () -> SyncOutcome) {
        running = true
        DispatchQueue.global().async {
            let outcome = block()
            DispatchQueue.main.async {
                running = false
                withAnimation { toast = outcome.message }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation { toast = nil }
                }
            }
        }
    }
}

extension String {
    func chunked(_ size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: min(size, count - $0))
            return String(self[start..<end])
        }
    }
}
