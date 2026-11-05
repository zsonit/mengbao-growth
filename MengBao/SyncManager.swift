import Foundation
import UIKit

// MARK: - 配对同步引擎
//
// 两台手机各自生成/输入同一个 6 位配对码，数据快照存放在云端一张按码索引的表里；
// 本地有改动 → 防抖 3 秒后「拉取 → 记录级合并 → 推送」，启动和手动同步走同一条链路。
// 合并规则与安卓 SyncManager.kt 逐条一致。

struct SyncOutcome {
    var ok: Bool
    var message: String
}

final class SyncManager: ObservableObject {

    static let shared = SyncManager()

    private static let endpoint = CloudCfg.endpoint
    private static let publishableKey = CloudCfg.publishableKey
    private static let rest = endpoint + "/.cloud/database/rest/v1/mengbao_sync"
    /// fetchRemote 的解密失败标记
    private static let undecryptable = "undecryptable"
    /// 云端还没有这一行的标记
    private static let empty = "empty"
    private static let defaults = UserDefaults.standard
    private static let keyCode = "sync_code"
    private static let keyDevice = "sync_device_id"
    private static let keyLastSync = "sync_last_at"
    private static let keySalt = "sync_salt"
    private static let keyRev = "sync_rev"
    private static let keyExec = "sync_exec_cmds"        // 已执行的管理指令 id
    private static let keyRemoved = "sync_removed_peers" // 已强制解绑/清除的设备 id -> 解绑时的 joinedAt
    /// 管理指令的有效期：离线超过这么久的设备不再收到旧指令
    private static let cmdTTL: TimeInterval = 3 * 86400
    /// 前台自动检查间隔：对端改完后最多这么久就能看到
    private static let pollInterval: TimeInterval = 6
    /// 本机改动后的防抖：够快、又能合并连续输入
    private static let debounce: TimeInterval = 1.2

    @Published var busy = false
    @Published var lastMessage: String?
    @Published var lastSyncAt: TimeInterval
    /// 对方手机已清空全部数据，等待用户选择「同步清除 / 忽略」
    @Published var remoteClearPrompt = false

    private var deviceId: String
    private var workItem: DispatchWorkItem?
    private var pollTimer: DispatchSourceTimer?

    /// 本机有未推送的修改；没有就不推，避免两端互推蹭出无限循环
    private var localDirty = false
    /// 同步进行中又来了新改动：等这一轮结束后必须补跑一次，否则这次改动会被丢掉
    private var retryPending = false
    private let syncLock = NSLock()
    private var isSyncing = false
    private var lastRev: Int64 = 0

    private init() {
        let d = Self.defaults.string(forKey: Self.keyDevice) ?? {
            let id = UUID().uuidString.prefix(8).uppercased()
            Self.defaults.set(String(id), forKey: Self.keyDevice)
            return String(id)
        }()
        deviceId = d
        lastSyncAt = Self.defaults.double(forKey: Self.keyLastSync)
        lastRev = Self.defaults.object(forKey: Self.keyRev) as? Int64 ?? 0
        // 启动后拉一次云端（延迟几秒，避开启动高峰）
        if Self.defaults.string(forKey: Self.keyCode) != nil {
            DispatchQueue.global().asyncAfter(deadline: .now() + 4) { [weak self] in
                _ = self?.syncNow(manual: false)
            }
        }
    }

    // MARK: 前台自动刷新

    /// App 回到前台：立即同步一次，然后开启自动检查
    func appDidBecomeActive() {
        guard pairedCode != nil else { return }
        startPolling()
        DispatchQueue.global().async { [weak self] in _ = self?.syncNow(manual: false) }
    }

    /// App 退到后台：停止自动检查（不耗电、不耗流量），但把还没推上去的改动抢推一次
    func appDidEnterBackground() {
        stopPolling()
        guard localDirty, pairedCode != nil else { return }
        AppLog.i("Sync", "退到后台，补推未上传的改动")
        var taskId: UIBackgroundTaskIdentifier = .invalid
        taskId = UIApplication.shared.beginBackgroundTask(withName: "mengbao.sync.flush") {
            if taskId != .invalid { UIApplication.shared.endBackgroundTask(taskId) }
            taskId = .invalid
        }
        DispatchQueue.global().async { [weak self] in
            _ = self?.syncNow(manual: false)
            DispatchQueue.main.async {
                if taskId != .invalid { UIApplication.shared.endBackgroundTask(taskId) }
                taskId = .invalid
            }
        }
    }

    private func startPolling() {
        stopPolling()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + Self.pollInterval, repeating: Self.pollInterval)
        timer.setEventHandler { [weak self] in self?.pollOnce() }
        timer.resume()
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    /// 轻量检查：只拉版本号，变了才真同步
    private func pollOnce() {
        guard let code = pairedCode else { return }
        // 本机有改动还没推成功（上一轮撞上忙碌被跳过了）：直接补推，别干等 rev 变化
        if localDirty {
            _ = syncNow(manual: false)
            return
        }
        let url = "\(Self.rest)?code=eq.\(code)&select=rev,updated_by&limit=1"
        guard let (resp, status) = Self.request(method: "GET", url: url, body: nil), status == 200,
              let data = resp,
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let row = arr.first
        else { return }
        let remoteRev = (row["rev"] as? NSNumber)?.int64Value ?? 0
        guard remoteRev != lastRev else { return }
        if (row["updated_by"] as? String) == deviceId {
            setRev(remoteRev)
            return
        }
        AppLog.i("Sync", "检测到对方有新数据（rev=\(remoteRev)），开始自动同步")
        _ = syncNow(manual: false)
    }

    private func setRev(_ rev: Int64) {
        lastRev = rev
        Self.defaults.set(rev, forKey: Self.keyRev)
    }

    var pairedCode: String? { Self.defaults.string(forKey: Self.keyCode) }

    // MARK: 配对

    func createPairing() -> SyncOutcome {
        for _ in 0..<6 {
            let code = String(format: "%06d", Int.random(in: 100000...999999))
            if codeExists(code) == false {
                Self.defaults.set(code, forKey: Self.keyCode)
                Self.defaults.removeObject(forKey: Self.keySalt)
                // 建码方即管理员：先登记再推，让这条登记随首次快照一起上去
                registerSelf("owner", silent: true)
                let r = syncNow(manual: true)
                return r.ok ? SyncOutcome(ok: true, message: "配对码 \(code) 已就绪") : r
            }
        }
        return SyncOutcome(ok: false, message: "配对码生成失败，请检查网络后重试")
    }

    /// 查码是否已被占用；nil = 网络失败
    private func codeExists(_ code: String) -> Bool? {
        guard let (resp, status) = Self.request(
            method: "GET",
            url: "\(Self.rest)?code=eq.\(code)&select=code&limit=1",
            body: nil,
        ), status == 200, let data = resp,
          let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }
        return !arr.isEmpty
    }

    func joinPairing(_ raw: String) -> SyncOutcome {
        let code = raw.trimmingCharacters(in: .whitespaces)
        guard code.count == 6, code.allSatisfy(\.isNumber) else {
            return SyncOutcome(ok: false, message: "配对码是 6 位数字")
        }
        Self.defaults.set(code, forKey: Self.keyCode)
        Self.defaults.removeObject(forKey: Self.keySalt)
        // 重新输入配对码＝重新接入：本机是空的时候要把「清空标记 / 删除墓碑」一起清掉，
        // 否则空设备会把自己的空状态推上去，把对方云端的数据盖掉
        if Store.shared.state.children.isEmpty {
            Store.shared.update({ s in
                s.clearedAt = nil
                s.tombstones = []
            }, silent: true)
        }
        let r = syncNow(manual: true)
        // 加入方登记为成员（非 silent：本机为空时上面 syncNow 可能没推成功，下次改动/手动同步会补推）
        registerSelf("member")
        return r.ok ? SyncOutcome(ok: true, message: "配对成功：\(code)") : r
    }

    /// 解除配对：只停止同步。本机资料、云端资料全部保留，只是不再互通。
    /// 多部手机共用一个配对码时（爷爷奶奶等），任何一台退出都不影响其他人。
    func unlink() -> SyncOutcome {
        clearLocal()
        return SyncOutcome(ok: true, message: "已解除配对：本机与云端资料都保留，只是不再同步")
    }

    private func clearLocal() {
        Self.defaults.removeObject(forKey: Self.keyCode)
        Self.defaults.removeObject(forKey: Self.keyLastSync)
        Self.defaults.removeObject(forKey: Self.keySalt)
        Self.defaults.removeObject(forKey: Self.keyRev)
        localDirty = false
        lastRev = 0
        stopPolling()
        DispatchQueue.main.async {
            self.lastSyncAt = 0
            self.lastMessage = nil
        }
    }

    // MARK: 设备管理（A 端建码后可管理加入的设备）

    struct PeerDevice: Identifiable, Hashable {
        let id: String
        let name: String
        let role: String
        let joinedAt: String
    }

    private static func nowLocal() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }

    private static func utcNow() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }

    private func deviceName() -> String {
        var name = UIDevice.current.name
        if name.count > 16 { name = String(name.prefix(16)) }
        return name
    }

    /// 把本机登记进设备表；已有条目时只在改名/角色变化时更新（removed 状态只由本机解绑记录控制）
    private func registerSelf(_ role: String, silent: Bool = false) {
        let id = deviceId
        let name = deviceName()
        let joined = Self.nowLocal()
        Store.shared.update({ s in
            if var d = s.devices[id] {
                guard d.name != name || d.role != role else { return }
                d.name = name
                if role == "owner" || d.role != "owner" { d.role = role }
                s.devices[id] = d
            } else {
                s.devices[id] = SyncDevice(name: name, role: role, joinedAt: joined)
            }
        }, silent: silent)
    }

    /// 本机是否管理员：自己是 owner，或整张表还没有 owner（老版本升级后首次进入时可接任）
    func isAdmin(_ state: AppState) -> Bool {
        if let me = state.devices[deviceId], me.role == "owner" { return true }
        return !state.devices.values.contains { $0.role == "owner" }
    }

    /// 老版本升级：整张表还没有 owner 时本机接任管理员
    func claimAdminIfVacant() {
        let devs = Store.shared.state.devices
        guard !devs.values.contains(where: { $0.role == "owner" }) else { return }
        registerSelf("owner")
    }

    /// 其他设备列表（已强制解绑/清除的不再显示，除非对方重新配对）
    func peers(_ state: AppState) -> [PeerDevice] {
        let removed = Self.defaults.dictionary(forKey: Self.keyRemoved) as? [String: String] ?? [:]
        return state.devices
            .filter { key, d in
                guard key != deviceId, d.role != "removed" else { return false }
                if let removedAt = removed[key] { return d.joinedAt > removedAt }
                return true
            }
            .map { PeerDevice(id: $0.key, name: $0.value.name, role: $0.value.role, joinedAt: $0.value.joinedAt) }
            .sorted { $0.joinedAt < $1.joinedAt }
    }

    /// 发指令：随本机改动在几秒内推上云端，对方打开 App 后自动执行
    private func sendCommand(_ type: String, to: String, payload: String? = nil) -> SyncOutcome {
        guard pairedCode != nil else { return SyncOutcome(ok: false, message: "尚未配对") }
        guard to != deviceId else { return SyncOutcome(ok: false, message: "不能对本机下发指令") }
        let cmd = SyncCommand(
            id: UUID().uuidString, from: deviceId, to: to,
            type: type, payload: payload, createdAt: Self.utcNow(), done: [],
        )
        Store.shared.update { s in
            s.commands.append(cmd)
        }
        if type != "scope" {
            // 本机立即把对方标记为已移除（不再显示在设备管理里）；对方重新配对（joinedAt 更新）会重新出现
            var removed = Self.defaults.dictionary(forKey: Self.keyRemoved) as? [String: String] ?? [:]
            removed[to] = Self.nowLocal()
            Self.defaults.set(removed, forKey: Self.keyRemoved)
        }
        let msg = type == "scope" ? "已发起定向同步，对方打开 App 后自动接收"
                                  : "指令已发出，对方打开 App 后自动执行"
        AppLog.i("Sync", "下发管理指令 \(type) → \(to)")
        return SyncOutcome(ok: true, message: msg)
    }

    /// 强制解绑：对方停止同步（对方资料保留）
    func forceUnbind(_ to: String) -> SyncOutcome { sendCommand("unbind", to: to) }

    /// 清除对方数据：对方解除配对并删除本机全部资料
    func wipeDevice(_ to: String) -> SyncOutcome { sendCommand("wipe", to: to) }

    /// 定向同步：把选中的类别（宝宝档案/生长/喂养/疫苗/待办/尺码/换牙/设置）推给对方覆盖
    func pushScope(_ to: String, scopes: [String]) -> SyncOutcome {
        guard !scopes.isEmpty else { return SyncOutcome(ok: false, message: "请先选择要同步的内容") }
        guard let data = try? JSONEncoder().encode(Store.shared.state),
              let obj = try? JSONSerialization.jsonObject(with: data)
        else { return SyncOutcome(ok: false, message: "数据编码失败") }
        let wrap: [String: Any] = ["scopes": scopes, "state": obj]
        guard let pd = try? JSONSerialization.data(withJSONObject: wrap, options: [.sortedKeys]),
              let p = String(data: pd, encoding: .utf8)
        else { return SyncOutcome(ok: false, message: "数据编码失败") }
        return sendCommand("scope", to: to, payload: p)
    }

    // MARK: 管理指令的接收与执行（两端逻辑一致）

    private var executedCmds: Set<String> {
        Set(Self.defaults.stringArray(forKey: Self.keyExec) ?? [])
    }

    private func markExecuted(_ id: String) {
        var s = executedCmds
        s.insert(id)
        Self.defaults.set(Array(s), forKey: Self.keyExec)
    }

    /// 取出「发给我、还没执行过」的指令：scope 的数据直接并入状态并打上 done；unbind/wipe 返回待执行动作。
    /// 在推送前调用，保证 done 标记随本轮一起上去。
    private func takeCommands(_ state: inout AppState) -> [String] {
        let executed = executedCmds
        let cmds = state.commands.filter { $0.to == deviceId && !$0.done.contains(deviceId) && !executed.contains($0.id) }
        guard !cmds.isEmpty else { return [] }
        var actions: [String] = []
        for c in cmds {
            if c.type == "scope", let payload = c.payload {
                state = Self.applyScope(payload, to: state)
            } else {
                actions.append(c.type)
            }
            if let i = state.commands.firstIndex(where: { $0.id == c.id }) {
                var done = state.commands[i].done
                done.append(deviceId)
                state.commands[i].done = done
            }
            markExecuted(c.id)
            AppLog.i("Sync", "执行管理指令 \(c.type)（来自 \(c.from)）")
        }
        return actions
    }

    /// 清理指令：所有其他设备都已执行（发起方视角）或已过期的，不再保存
    static func pruneCommands(_ cmds: [SyncCommand], devices: [String: SyncDevice], myId: String) -> [SyncCommand] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        let now = Date()
        let activeCount = max(1, devices.values.filter { $0.role != "removed" }.count)
        return cmds.filter { c in
            if let t = f.date(from: c.createdAt), now.timeIntervalSince(t) > cmdTTL { return false }
            if c.from == myId {
                let others = max(1, activeCount - 1)
                if Set(c.done).count >= others { return false }
            }
            return true
        }
    }

    /// 指令落地：unbind/wipe 在本轮推送前执行（done 标记随推送一起上去；即使推送失败指令也已生效）
    private func executeActions(_ types: [String]) {
        for t in types {
            if t == "unbind" {
                clearLocal()
                DispatchQueue.main.async { self.lastMessage = "管理员已解除本机配对" }
                AppLog.i("Sync", "已按管理员指令解除本机配对")
            } else if t == "wipe" {
                clearLocal()
                DispatchQueue.main.async {
                    Store.shared.update { s in
                        s.children = []
                        s.currentID = nil
                        s.tombstones = []
                        s.clearedAt = nil
                        s.commands = []
                    }
                    self.lastMessage = "管理员已清除本机数据"
                }
                AppLog.i("Sync", "已按管理员指令清除本机数据")
            }
        }
    }

    /// 应用定向同步数据：按类别把对方（管理员）的数据覆盖到本机，没选中的类别原样保留
    static func applyScope(_ payload: String, to state: AppState) -> AppState {
        guard let data = payload.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scopes = obj["scopes"] as? [String],
              let stateObj = obj["state"],
              let stateData = try? JSONSerialization.data(withJSONObject: stateObj),
              let incoming = try? JSONDecoder().decode(AppState.self, from: stateData)
        else {
            AppLog.w("Sync", "定向同步数据解析失败，忽略")
            return state
        }
        var out = state
        let now = Date()
        var children: [Child] = []
        for var c in out.children {
            guard let inc = incoming.children.first(where: { $0.id == c.id }) else {
                children.append(c)
                continue
            }
            if scopes.contains("profile") {
                c.name = inc.name
                c.sex = inc.sex
                c.birthDate = inc.birthDate
                c.avatar = inc.avatar
                c.avatarPath = inc.avatarPath
                c.bdaySameDayOn = inc.bdaySameDayOn
                c.bdaySameDayTime = inc.bdaySameDayTime
                c.bdayAdvanceOn = inc.bdayAdvanceOn
                c.bdayAdvanceDays = inc.bdayAdvanceDays
                c.bdayAdvanceTime = inc.bdayAdvanceTime
            }
            if scopes.contains("growth") { c.records = inc.records }
            if scopes.contains("feed") { c.feeds = inc.feeds }
            if scopes.contains("vaccine") {
                c.shots = inc.shots
                c.optVaccines = inc.optVaccines
                c.plans = inc.plans
                c.customShots = inc.customShots
            }
            if scopes.contains("todo") { c.todos = inc.todos }
            if scopes.contains("size") { c.sizes = inc.sizes }
            if scopes.contains("teeth") {
                c.teethFallen = inc.teethFallen
                c.teethDecay = inc.teethDecay
            }
            c.updatedAt = now   // 让这份覆盖在后续合并里成为权威版本
            children.append(c)
        }
        // 对方有、本机没有的宝宝：整份收下
        for inc in incoming.children where !out.children.contains(where: { $0.id == inc.id }) {
            var c = inc
            c.updatedAt = now
            children.append(c)
        }
        out.children = children
        if out.currentID == nil { out.currentID = out.children.first?.id }
        if scopes.contains("settings") { out.settings = incoming.settings }
        return out
    }

    // MARK: 触发

    func onDataChanged() {
        localDirty = true
        // 正在同步：记一笔，等这一轮结束立刻补跑（以前这里直接 return，这次改动就永久丢了）
        syncLock.lock()
        let syncing = isSyncing
        if syncing { retryPending = true }
        syncLock.unlock()
        if syncing { return }
        scheduleSync(after: Self.debounce)
    }

    /// 打一次延时的自动同步（连续改动会重置计时，合并成一次推送）
    private func scheduleSync(after seconds: TimeInterval) {
        workItem?.cancel()
        let item = DispatchWorkItem { [weak self] in _ = self?.syncNow(manual: false) }
        workItem = item
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds, execute: item)
    }

    /// 页面打开等场景主动拉一次（不阻塞调用线程）
    func requestSync() {
        syncLock.lock()
        if isSyncing {
            retryPending = true
            syncLock.unlock()
            return
        }
        syncLock.unlock()
        DispatchQueue.global().async { [weak self] in _ = self?.syncNow(manual: false) }
    }

    // MARK: 同步主链路

    @discardableResult
    func syncNow(manual: Bool) -> SyncOutcome {
        syncLock.lock()
        if isSyncing {
            retryPending = true
            syncLock.unlock()
            return SyncOutcome(ok: true, message: "同步进行中")
        }
        isSyncing = true
        syncLock.unlock()
        DispatchQueue.main.async { self.busy = true }

        defer {
            syncLock.lock()
            isSyncing = false
            let again = retryPending
            retryPending = false
            syncLock.unlock()
            DispatchQueue.main.async { self.busy = false }
            // 这一轮同步期间又存了新数据：立刻补跑一轮，避免改动丢失
            if again {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    _ = self?.syncNow(manual: false)
                }
            }
        }

        guard let code = pairedCode else { return SyncOutcome(ok: false, message: "尚未配对") }

        let store = Store.shared
        let local = store.state

        // 本机没数据分三种情况，必须区别对待：
        // 1) 全新安装 / 刚配对（没有清空标记、也没有删过宝宝）→ 直接拉对方的；
        // 2) 刚「清空全部数据」→ 有意的空，绝不拉回来，只把带标记的空状态推上去让对方弹窗；
        // 3) 只是把最后一个宝宝删了（有 child 墓碑、没有清空标记）→ 走正常合并，让墓碑同步出去。
        let localCleared = local.clearedAt ?? ""
        let hasChildTombstone = local.tombstones.contains { $0.hasPrefix("child:") }
        if local.children.isEmpty, localCleared.isEmpty, !hasChildTombstone {
            guard let snapshot = fetchRemote(code: code) else {
                let msg = manual ? "网络不可用" : ""
                return SyncOutcome(ok: false, message: msg)
            }
            if snapshot.updatedBy == Self.undecryptable {
                let msg = "云端数据无法解密，请重新输入配对码"
                DispatchQueue.main.async { self.lastMessage = msg }
                AppLog.w("Sync", msg)
                return SyncOutcome(ok: false, message: msg)
            }
            var remote = snapshot.state
            if remote.currentID == nil { remote.currentID = remote.children.first?.id }
            // 登记本机设备（老版本升级后第一次接入时补登；已有条目保留原角色）
            if remote.devices[deviceId] == nil {
                remote.devices[deviceId] = SyncDevice(name: deviceName(), role: "member", joinedAt: Self.nowLocal())
            }
            // 空机也可能收到管理指令（如刚配对就被定向同步），照常执行并把 done 标记推回去
            var actions: [String] = []
            var pulled = remote
            actions = takeCommands(&pulled)
            remote = pulled
            DispatchQueue.main.async { store.update { $0 = remote } }
            markSynced()
            if !actions.isEmpty {
                _ = upsert(code: code, state: remote)
                executeActions(actions)
            }
            DispatchQueue.main.async { self.lastMessage = "已拉取对方资料" }
            return SyncOutcome(ok: true, message: "已拉取对方资料")
        }
        if local.children.isEmpty, !localCleared.isEmpty {
            guard let snapshot = fetchRemote(code: code) else {
                let msg = manual ? "网络不可用" : ""
                return SyncOutcome(ok: false, message: msg)
            }
            if snapshot.updatedBy == Self.undecryptable {
                let msg = "云端数据无法解密，请重新输入配对码"
                DispatchQueue.main.async { self.lastMessage = msg }
                AppLog.w("Sync", msg)
                return SyncOutcome(ok: false, message: msg)
            }
            let remoteCleared = snapshot.state.clearedAt ?? ""
            if remoteCleared <= localCleared {
                // 云端还没收到这次清空（标记更旧）：把带标记的空状态推上去，让对方弹「同步清除 / 忽略」
                if remoteCleared < localCleared {
                    guard let status = upsert(code: code, state: local), (200...299).contains(status) else {
                        let msg = "推送失败：网络不可用"
                        DispatchQueue.main.async { if manual { self.lastMessage = msg } }
                        AppLog.w("Sync", msg)
                        return SyncOutcome(ok: false, message: msg)
                    }
                    localDirty = false
                    markSynced()
                    DispatchQueue.main.async { self.lastMessage = "已通知对方：本机已清空数据" }
                    return SyncOutcome(ok: true, message: "已通知对方：本机已清空数据")
                }
                // 对方已经收到过这条清空：如果对方点了「忽略」并把自己的数据推了上来，就把它接回来，
                // 避免「一端空、一端有数据」长期分叉；如果云端还是空的，就保持本机为空。
                let remoteHasData = !snapshot.state.children.isEmpty
                if remoteHasData {
                    var remote = snapshot.state
                    if remote.currentID == nil { remote.currentID = remote.children.first?.id }
                    DispatchQueue.main.async { store.update { $0 = remote } }
                    markSynced()
                    DispatchQueue.main.async { self.lastMessage = "对方选择了保留数据，已同步回来" }
                    return SyncOutcome(ok: true, message: "对方选择了保留数据，已同步回来")
                }
                DispatchQueue.main.async { self.lastMessage = "本机已清空，等对方确认" }
                return SyncOutcome(ok: true, message: "本机已清空，等对方确认")
            }
            // 对方比本机更晚清空：跟着对方的空状态走
            var remote = snapshot.state
            if remote.currentID == nil { remote.currentID = remote.children.first?.id }
            // 登记本机设备（老版本升级后第一次接入时补登；已有条目保留原角色）
            if remote.devices[deviceId] == nil {
                remote.devices[deviceId] = SyncDevice(name: deviceName(), role: "member", joinedAt: Self.nowLocal())
            }
            // 空机也可能收到管理指令（如刚配对就被定向同步），照常执行并把 done 标记推回去
            var actions: [String] = []
            var pulled = remote
            actions = takeCommands(&pulled)
            remote = pulled
            DispatchQueue.main.async { store.update { $0 = remote } }
            markSynced()
            if !actions.isEmpty {
                _ = upsert(code: code, state: remote)
                executeActions(actions)
            }
            DispatchQueue.main.async { self.lastMessage = "已拉取对方资料" }
            return SyncOutcome(ok: true, message: "已拉取对方资料")
        }

        let remoteSnapshot = fetchRemote(code: code)
        if let snapshot = remoteSnapshot, snapshot.updatedBy == Self.undecryptable {
            // 解密不了多半是两端密钥/配对码对不上，此时绝不能拿本机数据覆盖云端，否则另一端会被清空
            let msg = "云端数据无法解密，请重新输入配对码"
            DispatchQueue.main.async { self.lastMessage = msg }
            AppLog.w("Sync", msg)
            return SyncOutcome(ok: false, message: msg)
        }
        var merged = local
        // 云端还没有这一行（刚创建配对码）时必须推一次，否则对方永远拉不到数据
        var mustPush = localDirty || lastRev == 0 || remoteSnapshot?.updatedBy == Self.empty
        if let snapshot = remoteSnapshot {
            let (m, remoteClear) = Self.mergeState(local: local, remote: snapshot.state, myId: deviceId)
            merged = m
            if remoteClear {
                DispatchQueue.main.async { self.remoteClearPrompt = true }
            }
            if merged != local {
                DispatchQueue.main.async {
                    store.update({ s in
                        var m = merged
                        if m.currentID == nil { m.currentID = m.children.first?.id }
                        s = m
                    }, silent: true)
                }
                mustPush = true
            }
        }
        // 登记本机设备（老版本升级后第一次同步时补登）
        if merged.devices[deviceId] == nil {
            merged.devices[deviceId] = SyncDevice(name: deviceName(), role: "member", joinedAt: Self.nowLocal())
            mustPush = true
        }
        // 执行发给我的管理指令（scope 直接并入 merged，unbind/wipe 随后落地）
        var withCmds = merged
        let cmdActions = takeCommands(&withCmds)
        if !cmdActions.isEmpty {
            merged = withCmds
            mustPush = true
        }
        // 清理已完成/过期的管理指令
        let prunedCmds = Self.pruneCommands(merged.commands, devices: merged.devices, myId: deviceId)
        if prunedCmds.count != merged.commands.count {
            merged.commands = prunedCmds
            mustPush = true
        }
        // 强拆/清除类指令立即落地（本轮推送会带着 done 标记上去；即使推送失败指令也已执行）
        executeActions(cmdActions)

        // 本机没改、云端也没新东西：什么都不推，避免两端互相蹭出无限推送
        if !mustPush {
            DispatchQueue.main.async { self.lastMessage = "已是最新" }
            return SyncOutcome(ok: true, message: "已是最新")
        }

        guard let status = upsert(code: code, state: merged) else {
            DispatchQueue.main.async {
                if manual { self.lastMessage = "推送失败：网络不可用" }
            }
            AppLog.w("Sync", "推送失败：网络不可用")
            return SyncOutcome(ok: false, message: "推送失败：网络不可用")
        }
        guard (200...299).contains(status) else {
            let msg = "推送失败：HTTP \(status)"
            DispatchQueue.main.async { if manual { self.lastMessage = msg } }
            AppLog.w("Sync", msg)
            return SyncOutcome(ok: false, message: msg)
        }
        localDirty = false
        markSynced()
        // 指令执行产生的状态变化（done 标记、scope 覆盖）也要写回本机
        if merged != local {
            DispatchQueue.main.async {
                store.update({ s in
                    var m = merged
                    if m.currentID == nil { m.currentID = m.children.first?.id }
                    s = m
                }, silent: true)
            }
        }
        let msg = (remoteSnapshot != nil && merged != local) ? "已同步（收到对方的新记录）" : "已同步"
        DispatchQueue.main.async { self.lastMessage = msg }
        if manual { AppLog.i("Sync", "手动同步完成：\(merged.children.count) 个宝宝") }
        return SyncOutcome(ok: true, message: msg)
    }

    private func markSynced() {
        let now = Date().timeIntervalSince1970
        Self.defaults.set(now, forKey: Self.keyLastSync)
        DispatchQueue.main.async { self.lastSyncAt = now }
    }

    // MARK: 合并（与安卓保持一致）

    /// 返回合并结果 + 是否检测到「对方已清空全部数据」（本机还有数据时，由 UI 弹窗让用户选择）
    static func mergeState(local: AppState, remote: AppState, myId: String = "") -> (state: AppState, remoteClear: Bool) {
        let lc = local.clearedAt ?? ""
        let rc = remote.clearedAt ?? ""
        // 对方刚清空（clearedAt 更新）且本机还有数据：不自动合并，弹窗让用户选择「同步清除 / 忽略」
        if rc > lc, !local.children.isEmpty {
            var m = local
            m.clearedAt = remote.clearedAt
            return (m, true)
        }
        // 本机刚清空（clearedAt 更新）：不把对方的旧数据合并回来
        if lc > rc {
            return (local, false)
        }
        // 删除墓碑：两端取并集，一旦某条被删除，任何一侧的旧副本都不能再合并回来
        var tom = local.tombstones.union(remote.tombstones)
        // 疫苗墓碑撤销：只要任一端把某剂（重新）标记为已接种，就撤销该 key 的墓碑。
        // 否则历史上取消过一次的疫苗，云端旧墓碑会在每次合并时把新标记过滤掉，
        // 表现为「标记已接种后几秒又被弹回未接种」。
        let shotKeys = Set(local.children.flatMap { $0.shots.keys })
            .union(remote.children.flatMap { $0.shots.keys })
        for k in shotKeys { tom.remove("shot:\(k)") }
        var children: [Child] = []
        let remoteById = Dictionary(uniqueKeysWithValues: remote.children.map { ($0.id, $0) })
        var seen = Set<UUID>()
        for l in local.children where !tom.contains("child:\(l.id.uuidString)") {
            seen.insert(l.id)
            children.append(remoteById[l.id].map { mergeChild(l, $0, tombstones: tom) } ?? l)
        }
        for r in remote.children where !seen.contains(r.id) && !tom.contains("child:\(r.id.uuidString)") {
            children.append(r)
        }
        var out = local
        out.children = children
        out.tombstones = tom
        // 清空标记取较新的一个，两端对齐后不会再重复提示
        if let a = local.clearedAt, let b = remote.clearedAt {
            out.clearedAt = a > b ? a : b
        } else {
            out.clearedAt = local.clearedAt ?? remote.clearedAt
        }
        // 设备登记：每个条目只由那台设备自己写，key != myId 时以云端/对方为准，本机的保留
        var devs = remote.devices
        for (k, v) in local.devices where k == myId || devs[k] == nil { devs[k] = v }
        out.devices = devs
        // 管理指令：按 id 并集，done 取并集（谁执行了就记谁），按创建时间排序
        var byId: [String: SyncCommand] = [:]
        for c in local.commands { byId[c.id] = c }
        for c in remote.commands {
            if var e = byId[c.id] {
                e.done = Array(Set(e.done).union(c.done)).sorted()
                byId[c.id] = e
            } else {
                byId[c.id] = c
            }
        }
        out.commands = byId.values.sorted { $0.createdAt < $1.createdAt }
        return (out, false)
    }

    private static func authIsLocal(_ l: Child, _ r: Child) -> Bool {
        let lt = l.updatedAt ?? l.createdAt.addingTimeInterval(-50 * 365 * 86400)
        let rt = r.updatedAt ?? r.createdAt.addingTimeInterval(-50 * 365 * 86400)
        return lt >= rt
    }

    static func mergeChild(_ l: Child, _ r: Child, tombstones tom: Set<String> = []) -> Child {
        let authIsL = authIsLocal(l, r)
        let auth = authIsL ? l : r
        let other = authIsL ? r : l
        var out = auth
        // 合并前先按墓碑过滤，删除过的条目不会从另一端/云端旧快照里复活
        func alive(_ records: [GrowthRecord]) -> [GrowthRecord] { records.filter { !tom.contains("rec:\($0.id.uuidString)") } }
        func aliveFeeds(_ list: [FeedLog]) -> [FeedLog] { list.filter { !tom.contains("feed:\($0.id.uuidString)") } }
        func aliveSizes(_ list: [SizeRecord]) -> [SizeRecord] { list.filter { !tom.contains("size:\($0.id.uuidString)") } }
        func aliveTodos(_ list: [TodoItem]) -> [TodoItem] { list.filter { !tom.contains("todo:\($0.id.uuidString)") } }
        out.records = mergeRecords(alive(auth.records), alive(other.records))
        out.feeds = mergeById(aliveFeeds(auth.feeds), aliveFeeds(other.feeds))
        out.sizes = dedupeSizes(mergeById(aliveSizes(auth.sizes), aliveSizes(other.sizes)))
        out.todos = mergeById(aliveTodos(auth.todos), aliveTodos(other.todos))
        var shots = auth.shots
        for (k, v) in other.shots where shots[k] == nil { shots[k] = v }
        out.shots = shots.filter { !tom.contains("shot:\($0.key)") }
        // 脱落 / 龋齿按牙位并集，但已写删除墓碑的牙位不再从另一端/云端旧快照复活
        let cid = l.id.uuidString
        var teeth = (auth.teethFallen ?? [:]).filter { !tom.contains("toothFallen:\(cid):\($0.key)") }
        for (k, v) in (other.teethFallen ?? [:]) where teeth[k] == nil && !tom.contains("toothFallen:\(cid):\(k)") { teeth[k] = v }
        out.teethFallen = teeth.isEmpty ? nil : teeth
        var decay = (auth.teethDecay ?? [:]).filter { !tom.contains("toothDecay:\(cid):\($0.key)") }
        for (k, v) in (other.teethDecay ?? [:]) where decay[k] == nil && !tom.contains("toothDecay:\(cid):\(k)") { decay[k] = v }
        out.teethDecay = decay.isEmpty ? nil : decay
        return out
    }

    /// 生长记录按日期并集；同一天字段互补（权威端优先，空位用另一端补）
    static func mergeRecords(_ a: [GrowthRecord], _ b: [GrowthRecord]) -> [GrowthRecord] {
        var byDate = Dictionary(uniqueKeysWithValues: a.map { ($0.date, $0) })
        for r in b {
            guard let base = byDate[r.date] else {
                byDate[r.date] = r
                continue
            }
            var merged = base
            if merged.height == nil { merged.height = r.height }
            if merged.weight == nil { merged.weight = r.weight }
            if merged.footLength == nil { merged.footLength = r.footLength }
            if merged.headCirc == nil { merged.headCirc = r.headCirc }
            if merged.note.isEmpty { merged.note = r.note }
            byDate[r.date] = merged
        }
        return byDate.values.sorted { $0.date < $1.date }
    }

    private static func mergeById<T: Identifiable>(_ a: [T], _ b: [T]) -> [T] {
        guard !b.isEmpty else { return a }
        let ids = Set(a.map { $0.id })
        return a + b.filter { !ids.contains($0.id) }
    }

    /// 尺码去重（按天归并）：同一天只保留一条。
    /// 老版本每次保存都追加，同一天能堆出好几条（有的只有腰围、有的最全），
    /// 两端「取最新一条」时各挑到不同那条，看起来就像同步失败。
    /// 现在以「字段最全」的那条为底，用同一天其它条补齐空缺，冲突时以最全的为准。
    static func dedupeSizes(_ list: [SizeRecord]) -> [SizeRecord] {
        var byDay: [String: [SizeRecord]] = [:]
        for s in list where s.hasContent {
            byDay[s.dayKey, default: []].append(s)
        }
        return byDay.values.map { group -> SizeRecord in
            let base = group.max { a, b in
                if a.filledCount != b.filledCount { return a.filledCount < b.filledCount }
                return a.id.uuidString < b.id.uuidString
            }!
            return group.reduce(base) { acc, s in acc.fillMissingFrom(s) }
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: 网络

    /// 本机配对盐；没有则生成并保存
    private func localSalt() -> String {
        if let existing = Self.defaults.string(forKey: Self.keySalt) { return existing }
        let salt = SyncCrypto.newSalt()
        Self.defaults.set(salt, forKey: Self.keySalt)
        return salt
    }

    /// 采用云端的盐（两端必须用同一个盐才能互相解密）
    private func adoptSalt(_ remoteSalt: String) {
        guard !remoteSalt.isEmpty else { return }
        if Self.defaults.string(forKey: Self.keySalt) != remoteSalt {
            Self.defaults.set(remoteSalt, forKey: Self.keySalt)
        }
    }

    private func fetchRemote(code: String) -> (state: AppState, updatedBy: String)? {
        let url = "\(Self.rest)?code=eq.\(code)&select=payload,updated_by,rev&limit=1"
        guard let (resp, status) = Self.request(method: "GET", url: url, body: nil), status == 200,
              let data = resp,
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }
        guard let row = arr.first, let payload = row["payload"] as? [String: Any] else {
            return (AppState(), Self.empty)
        }
        setRev((row["rev"] as? NSNumber)?.int64Value ?? 0)

        // 新格式：端到端加密信封 —— 先采用云端盐，再用它解
        if payload["ct"] is String {
            if let salt = payload["salt"] as? String { adoptSalt(salt) }
            guard let plain = SyncCrypto.decrypt(code: code, envelope: payload),
                  let state = try? JSONDecoder().decode(AppState.self, from: Data(plain.utf8))
            else {
                AppLog.w("Sync", "云端密文无法解密（密钥不一致），本轮跳过，不覆盖云端")
                return (AppState(), Self.undecryptable)
            }
            return (state, row["updated_by"] as? String ?? "")
        }

        // 旧格式兼容（2.5.1 及以前）：包裹结构或直接就是互通 JSON
        let legacy = (payload["data"] as? [String: Any]) ?? payload
        guard let jsonData = try? JSONSerialization.data(withJSONObject: legacy, options: [.sortedKeys]),
              let state = try? JSONDecoder().decode(AppState.self, from: jsonData)
        else {
            AppLog.e("Sync", "云端数据解码失败")
            return nil
        }
        AppLog.i("Sync", "检测到旧版明文数据，本次同步后自动改成密文")
        return (state, row["updated_by"] as? String ?? "")
    }

    /// 推送：payload 列存加密信封，updated_by 记录来源设备；返回 HTTP 状态码（nil=网络失败）
    private func upsert(code: String, state: AppState) -> Int? {
        guard let dataJSON = try? JSONEncoder().encode(state),
              let plain = String(data: dataJSON, encoding: .utf8),
              let envelope = SyncCrypto.encrypt(code: code, plain: plain, salt: localSalt())
        else {
            AppLog.e("Sync", "本机加密失败")
            return nil
        }
        let body: [String: Any] = [
            "code": code,
            "payload": envelope,
            "updated_by": deviceId,
            "rev": Int64(Date().timeIntervalSince1970 * 1000),
        ]
        guard let rev = body["rev"] as? Int64,
              let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        guard let (_, status) = Self.request(
            method: "POST",
            url: "\(Self.rest)?on_conflict=code",
            body: data,
            extraHeaders: ["Prefer": "resolution=merge-duplicates"],
        ) else { return nil }
        if (200...299).contains(status) { setRev(rev) }
        return status
    }

    private static func request(method: String, url: String, body: Data?, extraHeaders: [String: String] = [:]) -> (Data?, Int)? {
        guard let url = URL(string: url) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 20
        req.setValue(publishableKey, forHTTPHeaderField: "x-wb-webapp-access-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = body
        var result: (Data?, Int)?
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            result = (data, status)
            semaphore.signal()
        }.resume()
        semaphore.wait()
        if result?.1 == 0 || result?.1 == nil {
            AppLog.w("Sync", "网络请求失败：\(method)")
        }
        return result
    }
}
