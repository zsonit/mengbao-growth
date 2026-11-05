import SwiftUI

// MARK: - 配对同步

/// 一台手机创建配对码，另一台输入同一个码，之后双方联网就自动双向同步全部资料。
/// 创建配对码的设备是「管理员」，可以在下面管理加入的设备（强制解绑 / 清除对方数据 / 定向同步指定类别）。
struct SyncView: View {
    @ObservedObject private var sync = SyncManager.shared
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var joinText = ""
    @State private var running = false
    @State private var toast: String?
    @State private var confirmTarget: SyncManager.PeerDevice?
    @State private var confirmType: String = "unbind"
    @State private var scopeTarget: SyncManager.PeerDevice?

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
            .onAppear { sync.claimAdminIfVacant() }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("☁️ 配对同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .alert(
                confirmType == "wipe" ? "清除「\(confirmTarget?.name ?? "")」的数据？"
                                      : "强制解绑「\(confirmTarget?.name ?? "")」？",
                isPresented: Binding(
                    get: { confirmTarget != nil },
                    set: { if !$0 { confirmTarget = nil } },
                ),
            ) {
                Button(confirmType == "wipe" ? "清除数据" : "解绑", role: .destructive) {
                    if let t = confirmTarget {
                        run { confirmType == "wipe" ? sync.wipeDevice(t.id) : sync.forceUnbind(t.id) }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(confirmType == "wipe"
                     ? "对方手机将解除配对，并删除本机全部资料（宝宝、喂养、生长、接种等），无法恢复。"
                     : "对方手机会立即停止同步（资料保留）；重新输入配对码可再次加入。")
            }
            .sheet(item: $scopeTarget) { peer in
                ScopePickerView(peer: peer) { scopes in
                    run { sync.pushScope(peer.id, scopes: scopes) }
                }
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
                .buttonStyle(SoftPressStyle())
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
                .buttonStyle(SoftPressStyle())
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

            deviceManagementCard

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
                    .buttonStyle(SoftPressStyle())
                    .disabled(sync.busy || running)

                    Button {
                        run { sync.unlink() }
                    } label: {
                        Text("解除配对")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(Palette.warn)
                    }
                    .buttonStyle(SoftPressStyle())
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

    // MARK: 设备管理（仅管理员可见）

    static let scopeOptions: [(key: String, label: String)] = [
        ("profile", "宝宝档案（姓名/生日/头像/生日提醒）"),
        ("growth", "生长记录（身高体重头围等）"),
        ("feed", "喂养记录"),
        ("vaccine", "疫苗接种（含自选/计划/其他接种）"),
        ("todo", "待办事项"),
        ("size", "尺码鞋服记录"),
        ("teeth", "换牙记录"),
        ("settings", "应用设置（家长身高/提醒等）"),
    ]

    @ViewBuilder
    private var deviceManagementCard: some View {
        if sync.isAdmin(store.state) {
            let list = sync.peers(store.state)
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("设备管理").font(.system(size: 13, weight: .bold)).foregroundColor(Palette.ink)
                    if list.isEmpty {
                        Text("还没有其他设备加入。家人手机输入这个配对码后，会出现在这里。")
                            .font(.system(size: 11.5))
                            .foregroundColor(Palette.subtle)
                            .lineSpacing(3)
                    } else {
                        ForEach(list) { peer in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(peer.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Palette.ink)
                                        Text("加入于 \(peer.joinedAt)")
                                            .font(.system(size: 10.5))
                                            .foregroundColor(Palette.subtle)
                                    }
                                    Spacer()
                                }
                                HStack(spacing: 20) {
                                    Button {
                                        scopeTarget = peer
                                    } label: {
                                        Text("同步数据")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Palette.purple)
                                    }
                                    .buttonStyle(SoftPressStyle())
                                    Button {
                                        confirmType = "unbind"
                                        confirmTarget = peer
                                    } label: {
                                        Text("强制解绑")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Palette.warn)
                                    }
                                    .buttonStyle(SoftPressStyle())
                                    Button {
                                        confirmType = "wipe"
                                        confirmTarget = peer
                                    } label: {
                                        Text("清除数据")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Palette.warn)
                                    }
                                    .buttonStyle(SoftPressStyle())
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        Text("· 同步数据：把选中的内容推送给对方覆盖（对方其他内容不动）\n· 强制解绑：对方立刻停止同步，资料保留\n· 清除数据：对方解除配对并删除全部资料，不可恢复\n· 指令在对方打开 App 后自动执行（3 天内有效）")
                            .font(.system(size: 10.5))
                            .foregroundColor(Palette.subtle)
                            .lineSpacing(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                withAnimation(Anim.pop) { toast = outcome.message }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation(Anim.pop) { toast = nil }
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

// MARK: - 定向同步内容选择

struct ScopePickerView: View {
    let peer: SyncManager.PeerDevice
    var onSend: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String> = []
    @State private var sending = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择要推送给「\(peer.name)」的内容，确认后覆盖对方手机上的对应数据；没选的类别对方保持不变。")
                        .font(.system(size: 12))
                        .foregroundColor(Palette.ink2)
                        .lineSpacing(4)
                        .padding(.bottom, 10)
                    ForEach(SyncView.scopeOptions, id: \.key) { opt in
                        Button {
                            if selection.contains(opt.key) { selection.remove(opt.key) } else { selection.insert(opt.key) }
                        } label: {
                            HStack {
                                Image(systemName: selection.contains(opt.key) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selection.contains(opt.key) ? Palette.purple : Palette.subtle)
                                Text(opt.label)
                                    .font(.system(size: 13.5))
                                    .foregroundColor(Palette.ink)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                    Button("全选 / 全不选") {
                        if selection.count == SyncView.scopeOptions.count { selection = [] } else { selection = Set(SyncView.scopeOptions.map(\.key)) }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Palette.purple)
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("同步数据给「\(peer.name)」")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(sending ? "发送中…" : "确认推送") {
                        sending = true
                        let scopes = Array(selection)
                        dismiss()
                        onSend(scopes)
                    }
                    .disabled(selection.isEmpty || sending)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
