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
    /// 前台自动检查间隔：对端改完后最多这么久就能看到
    private static let pollInterval: TimeInterval = 6
    /// 本机改动后的防抖：够快、又能合并连续输入
    private static let debounce: TimeInterval = 1.2

    @Published var busy = false
    @Published var lastMessage: String?
    @Published var lastSyncAt: TimeInterval

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
        let r = syncNow(manual: true)
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

        // 本机没数据：只拉不推，避免把空数据盖掉对方
        if local.children.isEmpty {
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
            DispatchQueue.main.async { store.update { $0 = remote } }
            markSynced()
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
            merged = Self.mergeState(local: local, remote: snapshot.state)
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

    static func mergeState(local: AppState, remote: AppState) -> AppState {
        // 删除墓碑：两端取并集，一旦某条被删除，任何一侧的旧副本都不能再合并回来
        let tom = local.tombstones.union(remote.tombstones)
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
        return out
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
        var teeth = auth.teethFallen ?? [:]
        for (k, v) in (other.teethFallen ?? [:]) where teeth[k] == nil { teeth[k] = v }
        out.teethFallen = teeth.isEmpty ? nil : teeth
        // 龋齿记录同样按牙位并集，缺失的一侧补上（同一颗牙各自记录时以权威端为准）
        var decay = auth.teethDecay ?? [:]
        for (k, v) in (other.teethDecay ?? [:]) where decay[k] == nil { decay[k] = v }
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
