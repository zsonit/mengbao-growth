package com.zsonit.mengbao.data

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.zsonit.mengbao.model.AppState
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.GrowthRecord
import com.zsonit.mengbao.model.SizeRecord
import com.zsonit.mengbao.model.SyncCommand
import com.zsonit.mengbao.model.SyncDevice
import com.zsonit.mengbao.model.ToothDecay
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/**
 * 配对同步引擎。
 *
 * 两台手机各自生成/输入同一个 6 位配对码，数据快照存放在云端一张按码索引的表里；
 * 本地有改动 → 防抖 3 秒后「拉取 → 记录级合并 → 推送」，App 启动和手动同步同一条链路。
 * 传输内容与「导出备份」完全相同的互通 JSON，全程仅存配对码对应的一行。
 *
 * 合并规则（两端实现保持一致）：
 * - 孩子：按 id 并集；同一孩子以 updatedAt 更新的一端为「权威端」；
 * - 权威端决定档案字段（姓名/生日/头像）与重复键记录的内容；
 * - 生长记录按日期并集、喂养/尺码/待办按 id 并集、接种/换牙按键并集，双方独有记录都保留；
 * - 显示设置以本机为准。
 */
object SyncManager {

    private const val ENDPOINT = "https://mengbao-sync.app.workbuddy.host"
    private const val PUBLISHABLE_KEY = "wbpk_z3Qd2DmHRK20lYTyzpjsTH_DG9v1WdRyKgkBsMLewH3mh5Br7EOcUlR"
    private const val REST = "$ENDPOINT/.cloud/database/rest/v1/mengbao_sync"
    private const val PREFS = "mengbao_sync"
    private const val KEY_CODE = "code"
    private const val KEY_DEVICE = "device_id"
    private const val KEY_LAST_SYNC = "last_sync_at"
    private const val KEY_SALT = "salt"
    private const val KEY_REV = "last_rev"
    /// 前台自动检查间隔：对端改完后最多这么久就能看到
    private const val POLL_MS = 6_000L
    /// 本机改动后的防抖：够快、又能合并连续输入
    private const val DEBOUNCE_MS = 1_200L
    /// fetchRemote 的解密失败标记
    private const val UNDECRYPTABLE = "undecryptable"
    /// 云端还没有这一行的标记
    private const val EMPTY = "empty"
    /// 已执行的管理指令 id 集合
    private const val KEY_EXEC = "exec_cmds"
    /// 已强制解绑/清除的设备：KEY_REMOVED_PREFIX + 设备id = 解绑时的 joinedAt
    private const val KEY_REMOVED_PREFIX = "removed_peer_"
    /// 管理指令的有效期：离线超过这么久的设备不再收到旧指令
    private const val CMD_TTL = 3L * 24 * 60 * 60 * 1000

    private var appContext: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pollHandler = Handler(Looper.getMainLooper())
    private val syncLock = Any()

    /** 本机有未推送的修改；没有就不推，避免两端互推蹭出无限循环 */
    @Volatile private var localDirty = false
    /** 同步进行中又来了新改动：等这一轮结束后必须补跑一次，否则这次改动会被丢掉 */
    @Volatile private var retryPending = false
    private var lastRev: Long = 0L

    private val pollRunnable = object : Runnable {
        override fun run() {
            Thread { pollOnce() }.start()
            pollHandler.postDelayed(this, POLL_MS)
        }
    }

    // UI 可观察状态
    var busy by mutableStateOf(false)
        private set
    var lastMessage by mutableStateOf<String?>(null)
        private set
    var lastSyncAt by mutableStateOf(0L)
        private set

    val pairedCode: String?
        get() = prefs()?.getString(KEY_CODE, null)

    fun bootstrap(context: Context) {
        if (appContext != null) return
        appContext = context.applicationContext
        lastSyncAt = prefs()?.getLong(KEY_LAST_SYNC, 0L) ?: 0L
        lastRev = prefs()?.getLong(KEY_REV, 0L) ?: 0L
        // 启动后拉一次云端（延迟几秒，避开启动高峰）
        if (pairedCode != null) {
            mainHandler.postDelayed({ Thread { syncNow(manual = false) }.start() }, 4000)
        }
    }

    // MARK: 前台自动刷新

    /** App 回到前台：立即同步一次，然后开启轮询 */
    fun onForeground() {
        if (pairedCode == null) return
        pollHandler.removeCallbacks(pollRunnable)
        pollHandler.postDelayed(pollRunnable, 1200)
    }

    /** App 退到后台：停止轮询（不耗电、不耗流量），但把还没推上去的改动抢推一次 */
    fun onBackground() {
        pollHandler.removeCallbacks(pollRunnable)
        if (localDirty && !busy) {
            AppLog.i("Sync", "退到后台，补推未上传的改动")
            Thread { syncNow(manual = false) }.start()
        }
    }

    /** 轻量检查：只拉版本号，变了才真同步 */
    private fun pollOnce() {
        if (busy) return
        val code = pairedCode ?: return
        // 本机有改动还没推成功（上一轮撞上忙碌被跳过了）：直接补推，别干等 rev 变化
        if (localDirty) {
            syncNow(manual = false)
            return
        }
        val (body, _) = http("GET", "$REST?code=eq.$code&select=rev,updated_by&limit=1", null)
        if (body == null) return
        val row = runCatching { JSONArray(body).optJSONObject(0) }.getOrNull() ?: return
        val remoteRev = row.optLong("rev", 0L)
        val by = row.optString("updated_by")
        if (remoteRev == lastRev) return
        if (by == deviceId()) {
            // 自己推的那次没记上版本号，补上即可
            setRev(remoteRev)
            return
        }
        AppLog.i("Sync", "检测到对方有新数据（rev=$remoteRev），开始自动同步")
        syncNow(manual = false)
    }

    private fun setRev(rev: Long) {
        lastRev = rev
        prefs()?.edit()?.putLong(KEY_REV, rev)?.apply()
    }

    private fun prefs() = appContext?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun deviceId(): String {
        val p = prefs() ?: return "unknown"
        var id = p.getString(KEY_DEVICE, null)
        if (id == null) {
            id = UUID.randomUUID().toString().substring(0, 8)
            p.edit().putString(KEY_DEVICE, id).apply()
        }
        return id
    }

    // MARK: 配对操作（在调用方线程执行网络；UI 层用 Thread 包裹）

    /** 创建配对码：随机 6 位数字，云端已占用则换号重试；创建后立即推送本机快照 */
    fun createPairing(): SyncResult {
        repeat(6) {
            val code = (100000..999999).random().toString()
            val exists = codeExists(code)
            if (exists == false) {
                prefs()?.edit()?.putString(KEY_CODE, code)?.remove(KEY_SALT)?.apply()
                // 建码方即管理员：先登记再推，让这条登记随首次快照一起上去
                registerSelf("owner", silent = true)
                val r = syncNow(manual = true)
                return if (r.ok) SyncResult(true, "配对码 $code 已就绪") else r
            }
        }
        return SyncResult(false, "配对码生成失败，请检查网络后重试")
    }

    /** 加入对方的配对码：存码后立即拉取合并 */
    fun joinPairing(code: String): SyncResult {
        val c = code.trim()
        if (!Regex("\\d{6}").matches(c)) return SyncResult(false, "配对码是 6 位数字")
        prefs()?.edit()?.putString(KEY_CODE, c)?.remove(KEY_SALT)?.apply()
        // 重新输入配对码＝重新接入：本机是空的时候要把「清空标记 / 删除墓碑」一起清掉，
        // 否则空设备会把自己的空状态推上去，把对方云端的数据盖掉
        if (Store.state.children.isEmpty()) {
            Store.suppressSync = true
            try {
                Store.update { it.copy(clearedAt = null, tombstones = emptySet()) }
            } finally {
                Store.suppressSync = false
            }
        }
        val r = syncNow(manual = true)
        // 加入方登记为成员（非 silent：本机为空时上面 syncNow 可能没推成功，下次改动/手动同步会补推）
        registerSelf("member")
        return if (r.ok) SyncResult(true, "配对成功：$c") else r
    }

    /**
     * 解除配对：只停止同步。本机资料、云端资料全部保留，只是不再互通。
     * 多部手机共用一个配对码时（爷爷奶奶等），任何一台退出都不影响其他人。
     */
    fun unlink(): SyncResult {
        clearLocal()
        return SyncResult(true, "已解除配对：本机与云端资料都保留，只是不再同步")
    }

    private fun clearLocal() {
        prefs()?.edit()?.clear()?.apply()
        lastSyncAt = 0
        lastMessage = null
        localDirty = false
        lastRev = 0L
        pollHandler.removeCallbacks(pollRunnable)
    }

    // MARK: 设备管理（A 端建码后可管理加入的设备）

    data class PeerDevice(val id: String, val name: String, val role: String, val joinedAt: String)

    private fun nowLocal(): String =
        SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date())

    private fun utcNow(): String {
        val f = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
        f.timeZone = TimeZone.getTimeZone("UTC")
        return f.format(Date())
    }

    private fun deviceName(): String = try {
        val custom = Settings.Global.getString(appContext?.contentResolver, "device_name")
        (custom ?: Build.MODEL).take(16)
    } catch (e: Exception) {
        Build.MODEL.take(16)
    }

    /** 把本机登记进设备表；已有条目时只在改名/角色变化时更新 */
    private fun registerSelf(role: String, silent: Boolean = false) {
        val id = deviceId()
        val name = deviceName()
        val joined = nowLocal()
        if (silent) Store.suppressSync = true
        try {
            Store.update { s ->
                val cur = s.devices[id]
                when {
                    cur == null -> s.copy(devices = s.devices + (id to SyncDevice(name, role, joined)))
                    cur.name != name || cur.role != role -> {
                        val newRole = if (role == "owner" || cur.role != "owner") role else cur.role
                        s.copy(devices = s.devices + (id to cur.copy(name = name, role = newRole)))
                    }
                    else -> s
                }
            }
        } finally {
            if (silent) Store.suppressSync = false
        }
    }

    /** 本机是否管理员：自己是 owner，或整张表还没有 owner（老版本升级后首次进入时可接任） */
    fun isAdmin(state: AppState): Boolean {
        state.devices[deviceId()]?.let { if (it.role == "owner") return true }
        return state.devices.values.none { it.role == "owner" }
    }

    /** 老版本升级：整张表还没有 owner 时本机接任管理员 */
    fun claimAdminIfVacant() {
        if (Store.state.devices.values.none { it.role == "owner" }) registerSelf("owner")
    }

    private fun removedPeers(): Map<String, String> {
        val p = prefs() ?: return emptyMap()
        return p.all
            .filterKeys { it.startsWith(KEY_REMOVED_PREFIX) }
            .mapKeys { it.key.removePrefix(KEY_REMOVED_PREFIX) }
            .mapValues { it.value as? String ?: "" }
    }

    /** 其他设备列表（已强制解绑/清除的不再显示，除非对方重新配对） */
    fun peers(state: AppState): List<PeerDevice> {
        val removed = removedPeers()
        val myId = deviceId()
        return state.devices
            .filter { (id, d) ->
                if (id == myId || d.role == "removed") return@filter false
                removed[id]?.let { d.joinedAt <= it } != true
            }
            .map { PeerDevice(it.key, it.value.name, it.value.role, it.value.joinedAt) }
            .sortedBy { it.joinedAt }
    }

    /** 发指令：随本机改动在几秒内推上云端，对方打开 App 后自动执行 */
    private fun sendCommand(type: String, to: String, payload: String? = null): SyncResult {
        if (pairedCode == null) return SyncResult(false, "尚未配对")
        if (to == deviceId()) return SyncResult(false, "不能对本机下发指令")
        val cmd = SyncCommand(
            id = UUID.randomUUID().toString(),
            from = deviceId(),
            to = to,
            type = type,
            payload = payload,
            createdAt = utcNow(),
        )
        Store.update { it.copy(commands = it.commands + cmd) }
        if (type != "scope") {
            // 本机立即把对方标记为已移除（不再显示在设备管理里）；对方重新配对（joinedAt 更新）会重新出现
            prefs()?.edit()?.putString(KEY_REMOVED_PREFIX + to, nowLocal())?.apply()
        }
        AppLog.i("Sync", "下发管理指令 $type → $to")
        return SyncResult(
            true,
            if (type == "scope") "已发起定向同步，对方打开 App 后自动接收"
            else "指令已发出，对方打开 App 后自动执行",
        )
    }

    /** 强制解绑：对方停止同步（对方资料保留） */
    fun forceUnbind(to: String): SyncResult = sendCommand("unbind", to)

    /** 清除对方数据：对方解除配对并删除本机全部资料 */
    fun wipeDevice(to: String): SyncResult = sendCommand("wipe", to)

    /** 定向同步：把选中的类别（宝宝档案/生长/喂养/疫苗/待办/尺码/换牙/设置）推给对方覆盖 */
    fun pushScope(to: String, scopes: List<String>): SyncResult {
        if (scopes.isEmpty()) return SyncResult(false, "请先选择要同步的内容")
        val payload = try {
            JSONObject()
                .put("scopes", JSONArray(scopes))
                .put("state", JSONObject(JsonCodec.encode(Store.state)))
                .toString()
        } catch (e: Exception) {
            return SyncResult(false, "数据编码失败")
        }
        return sendCommand("scope", to, payload)
    }

    // MARK: 管理指令的接收与执行（两端逻辑一致）

    private fun executedCmds(): Set<String> =
        prefs()?.getStringSet(KEY_EXEC, emptySet())?.toSet() ?: emptySet()

    private fun markExecuted(id: String) {
        prefs()?.edit()?.putStringSet(KEY_EXEC, executedCmds() + id)?.apply()
    }

    /** 取出「发给我、还没执行过」的指令：scope 的数据直接并入状态并打上 done；unbind/wipe 返回待执行动作 */
    private fun takeCommands(state: AppState): Pair<AppState, List<String>> {
        val executed = executedCmds()
        val myId = deviceId()
        val mine = state.commands.filter { it.to == myId && myId !in it.done && it.id !in executed }
        if (mine.isEmpty()) return state to emptyList()
        var s = state
        val actions = mutableListOf<String>()
        for (c in mine) {
            if (c.type == "scope" && c.payload != null) {
                s = applyScope(c.payload, s)
            } else {
                actions.add(c.type)
            }
            s = s.copy(commands = s.commands.map {
                if (it.id == c.id) it.copy(done = (it.done + myId).distinct()) else it
            })
            markExecuted(c.id)
            AppLog.i("Sync", "执行管理指令 ${c.type}（来自 ${c.from}）")
        }
        return s to actions
    }

    /** 清理指令：所有其他设备都已执行（发起方视角）或已过期的，不再保存 */
    private fun pruneCommands(cmds: List<SyncCommand>, devices: Map<String, SyncDevice>, myId: String): List<SyncCommand> {
        val f = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
        f.timeZone = TimeZone.getTimeZone("UTC")
        val now = System.currentTimeMillis()
        val activeCount = maxOf(1, devices.values.count { it.role != "removed" })
        return cmds.filter { c ->
            val age = try { now - (f.parse(c.createdAt)?.time ?: 0L) } catch (e: Exception) { 0L }
            if (age > CMD_TTL) return@filter false
            if (c.from == myId) {
                val others = maxOf(1, activeCount - 1)
                if (c.done.distinct().size >= others) return@filter false
            }
            true
        }
    }

    /** 指令落地：unbind/wipe 在推送完成后执行（scope 已在 takeCommands 里并入状态） */
    private fun executeActions(types: List<String>) {
        for (t in types) {
            when (t) {
                "unbind" -> {
                    clearLocal()
                    lastMessage = "管理员已解除本机配对"
                    AppLog.i("Sync", "已按管理员指令解除本机配对")
                }
                "wipe" -> {
                    clearLocal()
                    Store.update {
                        it.copy(
                            children = emptyList(),
                            currentId = null,
                            tombstones = emptySet(),
                            clearedAt = null,
                            commands = emptyList(),
                        )
                    }
                    lastMessage = "管理员已清除本机数据"
                    AppLog.i("Sync", "已按管理员指令清除本机数据")
                }
            }
        }
    }

    /** 应用定向同步数据：按类别把对方（管理员）的数据覆盖到本机，没选中的类别原样保留 */
    private fun applyScope(payload: String, state: AppState): AppState {
        val obj = try { JSONObject(payload) } catch (e: Exception) {
            AppLog.w("Sync", "定向同步数据解析失败，忽略")
            return state
        }
        val scopes = obj.optJSONArray("scopes")?.let { arr -> (0 until arr.length()).map { arr.optString(it) } } ?: emptyList()
        val incoming: AppState = try {
            JsonCodec.decode(obj.getJSONObject("state").toString())
        } catch (e: Exception) {
            AppLog.w("Sync", "定向同步数据解析失败，忽略")
            return state
        }
        val now = LocalDateTime.now()
        val incomingById = incoming.children.associateBy { it.id }
        val existingIds = state.children.map { it.id }.toSet()
        val children = state.children.map { c ->
            val inc = incomingById[c.id] ?: return@map c
            var out = c
            if ("profile" in scopes) {
                out = out.copy(
                    name = inc.name, sex = inc.sex, birthDate = inc.birthDate,
                    avatar = inc.avatar, avatarPath = inc.avatarPath,
                    bdaySameDayOn = inc.bdaySameDayOn, bdaySameDayTime = inc.bdaySameDayTime,
                    bdayAdvanceOn = inc.bdayAdvanceOn, bdayAdvanceDays = inc.bdayAdvanceDays,
                    bdayAdvanceTime = inc.bdayAdvanceTime,
                )
            }
            if ("growth" in scopes) out = out.copy(records = inc.records)
            if ("feed" in scopes) out = out.copy(feeds = inc.feeds)
            if ("vaccine" in scopes) {
                out = out.copy(shots = inc.shots, optVaccines = inc.optVaccines, plans = inc.plans, customShots = inc.customShots)
            }
            if ("todo" in scopes) out = out.copy(todos = inc.todos)
            if ("size" in scopes) out = out.copy(sizes = inc.sizes)
            if ("teeth" in scopes) out = out.copy(teethFallen = inc.teethFallen, teethDecay = inc.teethDecay)
            out.copy(updatedAt = now)   // 让这份覆盖在后续合并里成为权威版本
        } + incoming.children.filter { it.id !in existingIds }.map { it.copy(updatedAt = now) }
        return state.copy(
            children = children,
            currentId = state.currentId ?: children.firstOrNull()?.id,
            settings = if ("settings" in scopes) incoming.settings else state.settings,
        )
    }

    // MARK: 同步主链路

    fun onDataChanged() {
        localDirty = true
        // 正在同步：记一笔，等这一轮结束立刻补推（以前这里直接 return，改动就永远丢了）
        if (busy) {
            retryPending = true
            return
        }
        scheduleSync(DEBOUNCE_MS)
    }

    /** 打一次延时的自动同步（连续改动会重置计时，合并成一次推送） */
    private fun scheduleSync(delayMs: Long) {
        mainHandler.removeCallbacksAndMessages(null)
        mainHandler.postDelayed({ Thread { syncNow(manual = false) }.start() }, delayMs)
    }

    /** 页面打开等场景主动拉一次（不阻塞调用线程） */
    fun requestSync() {
        if (busy) {
            retryPending = true
            return
        }
        Thread { syncNow(manual = false) }.start()
    }

    fun syncNow(manual: Boolean): SyncResult = synchronized(syncLock) {
        val context = appContext
        val code = pairedCode
        if (context == null || code == null) return SyncResult(false, "尚未配对")
        if (Store.state.children.isEmpty()) {
            // 本机没数据分三种情况，必须区别对待：
            // 1) 全新安装 / 刚配对（没有清空标记、也没删过宝宝）→ 直接拉对方的；
            // 2) 刚「清空全部数据」→ 有意的空，绝不拉回来，只把带标记的空状态推上去让对方弹窗；
            // 3) 只是把最后一个宝宝删了（有 child 墓碑、没有清空标记）→ 走正常合并，让墓碑同步出去。
            val local = Store.state
            val localCleared = local.clearedAt.orEmpty()
            val hasChildTombstone = local.tombstones.any { it.startsWith("child:") }
            if (localCleared.isEmpty() && !hasChildTombstone) {
                val remote = fetchRemote(code)
                    ?: return if (manual) SyncResult(true, "云端暂无数据") else SyncResult(false, "云端暂无数据")
                if (remote.updatedBy == UNDECRYPTABLE) {
                    val msg = "云端数据无法解密，请重新输入配对码"
                    lastMessage = msg
                    return SyncResult(false, msg)
                }
                applyRemote(context, code, remote)
                return SyncResult(true, "已拉取对方资料")
            }
            if (localCleared.isNotEmpty()) {
                val remote = fetchRemote(code)
                    ?: return if (manual) SyncResult(true, "云端暂无数据") else SyncResult(false, "云端暂无数据")
                if (remote.updatedBy == UNDECRYPTABLE) {
                    val msg = "云端数据无法解密，请重新输入配对码"
                    lastMessage = msg
                    return SyncResult(false, msg)
                }
                val remoteCleared = remote.state.clearedAt.orEmpty()
                if (remoteCleared <= localCleared) {
                    if (remoteCleared < localCleared) {
                        // 云端还没收到这次清空：把带标记的空状态推上去，让对方弹「同步清除 / 忽略」
                        val resp = upsert(code, local)
                        if (!resp.ok) {
                            lastMessage = if (manual) "推送失败：${resp.message}" else null
                            AppLog.w("Sync", "推送失败：${resp.message}")
                            return SyncResult(false, "推送失败：${resp.message}")
                        }
                        localDirty = false
                        val ts = System.currentTimeMillis()
                        lastSyncAt = ts
                        prefs()?.edit()?.putLong(KEY_LAST_SYNC, ts)?.apply()
                        lastMessage = "已通知对方：本机已清空数据"
                        return SyncResult(true, lastMessage!!)
                    }
                    // 对方已经收到过这条清空：如果对方点了「忽略」并把自己的数据推了上来，就把它接回来，
                    // 避免「一端空、一端有数据」长期分叉；如果云端还是空的，就保持本机为空。
                    if (remote.state.children.isNotEmpty()) {
                        val r = applyRemote(context, code, remote)
                        lastMessage = "对方选择了保留数据，已同步回来"
                        return SyncResult(r.ok, lastMessage!!)
                    }
                    lastMessage = "本机已清空，等对方确认"
                    return SyncResult(true, lastMessage!!)
                }
                // 对方比本机更晚清空：跟着对方的空状态走
                applyRemote(context, code, remote)
                return SyncResult(true, "已拉取对方资料")
            }
        }
        busy = true
        try {
            val remote = fetchRemote(code) // null=网络失败；空 payload=对方还没推过
            if (remote != null && remote.updatedBy == UNDECRYPTABLE) {
                // 解密不了多半是两端密钥/配对码对不上，此时绝不能拿本机数据覆盖云端，否则另一端会被清空
                val msg = "云端数据无法解密，请重新输入配对码"
                lastMessage = msg
                AppLog.w("Sync", msg)
                return SyncResult(false, msg)
            }
            val local = Store.state
            var merged = local
            // 云端还没有这一行（刚创建配对码）时必须推一次，否则对方永远拉不到数据
            var mustPush = localDirty || lastRev == 0L || remote?.updatedBy == EMPTY
            if (remote != null) {
                val (m, remoteClear) = mergeState(local, remote.state, deviceId())
                merged = m
                if (remoteClear) clearPrompt = true
                if (merged != local) {
                    Store.suppressSync = true
                    try {
                        Store.update { merged.copy(currentId = merged.currentId ?: merged.children.firstOrNull()?.id) }
                    } finally {
                        Store.suppressSync = false
                    }
                    mustPush = true
                }
            }
            // 登记本机设备（老版本升级后第一次同步时补登）
            val myId = deviceId()
            if (merged.devices[myId] == null) {
                merged = merged.copy(devices = merged.devices + (myId to SyncDevice(deviceName(), "member", nowLocal())))
                mustPush = true
            }
            // 执行发给我的管理指令（scope 直接并入 merged，unbind/wipe 随后落地）
            var cmdActions: List<String> = emptyList()
            run {
                val (s2, actions) = takeCommands(merged)
                if (actions.isNotEmpty()) {
                    merged = s2
                    cmdActions = actions
                    mustPush = true
                }
            }
            // 清理已完成/过期的管理指令
            val prunedCmds = pruneCommands(merged.commands, merged.devices, myId)
            if (prunedCmds.size != merged.commands.size) {
                merged = merged.copy(commands = prunedCmds)
                mustPush = true
            }
            // 强拆/清除类指令立即落地（本轮推送会带着 done 标记上去；即使推送失败指令也已执行）
            executeActions(cmdActions)
            if (!mustPush) {
                // 本机没改、云端也没新东西：什么都不推，避免两端互相蹭出无限推送
                lastMessage = "已是最新"
                return SyncResult(true, "已是最新")
            }
            val resp = upsert(code, merged)
            if (!resp.ok) {
                lastMessage = if (manual) "推送失败：${resp.message}" else null
                AppLog.w("Sync", "推送失败：${resp.message}")
                return SyncResult(false, "推送失败：${resp.message}")
            }
            localDirty = false
            val ts = System.currentTimeMillis()
            lastSyncAt = ts
            prefs()?.edit()?.putLong(KEY_LAST_SYNC, ts)?.apply()
            // 指令执行产生的状态变化（done 标记、scope 覆盖）也要写回本机
            if (merged != local) {
                Store.suppressSync = true
                try {
                    Store.update { merged.copy(currentId = merged.currentId ?: merged.children.firstOrNull()?.id) }
                } finally {
                    Store.suppressSync = false
                }
            }
            val mergedNew = remote != null && merged != local
            lastMessage = if (mergedNew) "已同步（收到对方的新记录）" else "已同步"
            if (manual) AppLog.i("Sync", "手动同步完成：${merged.children.size} 个宝宝")
            return SyncResult(true, lastMessage ?: "已同步")
        } catch (e: Exception) {
            AppLog.e("Sync", "同步异常：$e")
            lastMessage = if (manual) "同步失败：${e.message}" else null
            return SyncResult(false, "同步失败：${e.message}")
        } finally {
            busy = false
            // 这一轮同步期间又存了新数据：立刻补跑一轮，避免改动丢失
            if (retryPending) {
                retryPending = false
                scheduleSync(600)
            }
        }
    }

    /** 首次绑定（本机无数据时）：直接采用对方数据 */
    private fun applyRemote(context: Context, code: String, remote: RemoteSnapshot): SyncResult {
        busy = true
        try {
            var st = remote.state.copy(currentId = remote.state.currentId ?: remote.state.children.firstOrNull()?.id)
            // 登记本机设备（老版本升级后第一次以空机接入时补登）
            val myId = deviceId()
            if (st.devices[myId] == null) {
                st = st.copy(devices = st.devices + (myId to SyncDevice(deviceName(), "member", nowLocal())))
            }
            // 空机也可能收到管理指令（如刚配对就被定向同步），照常执行并把 done 标记推回去
            var actions: List<String> = emptyList()
            run {
                val (s2, a) = takeCommands(st)
                st = s2
                actions = a
            }
            Store.suppressSync = true
            try {
                Store.update { st }
            } finally {
                Store.suppressSync = false
            }
            val payload = Store.state
            val resp = upsert(code, payload)
            if (resp.ok) localDirty = false
            if (actions.isNotEmpty()) executeActions(actions)
            val ts = System.currentTimeMillis()
            lastSyncAt = ts
            prefs()?.edit()?.putLong(KEY_LAST_SYNC, ts)?.apply()
            lastMessage = if (resp.ok) "已拉取对方资料" else "拉取成功但推送失败"
            return SyncResult(resp.ok, lastMessage ?: "已拉取")
        } finally {
            busy = false
        }
    }

    // MARK: 合并

    /** 对方手机已清空全部数据，等待用户选择「同步清除 / 忽略」 */
    var clearPrompt by mutableStateOf(false)

    /** 返回合并结果 + 是否检测到「对方已清空全部数据」（本机还有数据时，由 UI 弹窗让用户选择） */
    private fun mergeState(local: AppState, remote: AppState, myId: String): Pair<AppState, Boolean> {
        val lc = local.clearedAt.orEmpty()
        val rc = remote.clearedAt.orEmpty()
        // 对方刚清空（clearedAt 更新）且本机还有数据：不自动合并，弹窗让用户选择「同步清除 / 忽略」
        if (rc > lc && local.children.isNotEmpty()) {
            return local.copy(clearedAt = remote.clearedAt) to true
        }
        // 本机刚清空（clearedAt 更新）：不把对方的旧数据合并回来
        if (lc > rc) {
            return local to false
        }
        // 删除墓碑：两端取并集，条目一旦删除，任何一侧的旧副本都不能再合并回来
        val tom = (local.tombstones + remote.tombstones).toMutableSet()
        // 疫苗墓碑撤销：只要任一端把某剂（重新）标记为已接种，就撤销该 key 的墓碑。
        // 否则历史上取消过一次的疫苗，云端旧墓碑会在每次合并时把新标记过滤掉，
        // 表现为「标记已接种后几秒又被弹回未接种」。
        val shotKeys = (local.children.flatMap { it.shots.keys } + remote.children.flatMap { it.shots.keys }).toSet()
        shotKeys.forEach { tom.remove("shot:$it") }
        val children = mutableListOf<Child>()
        val remoteById = remote.children.associateBy { it.id }
        val seen = mutableSetOf<String>()
        for (l in local.children) {
            if ("child:${l.id}" in tom) continue
            seen.add(l.id)
            children.add(remoteById[l.id]?.let { mergeChild(l, it, tom) } ?: l)
        }
        for (r in remote.children) {
            if (r.id !in seen && "child:${r.id}" !in tom) children.add(r)
        }
        // 清空标记取较新的一个，两端对齐后不会再重复提示
        val cleared = when {
            local.clearedAt != null && remote.clearedAt != null -> maxOf(local.clearedAt!!, remote.clearedAt!!)
            else -> local.clearedAt ?: remote.clearedAt
        }
        var out = local.copy(children = children, tombstones = tom, clearedAt = cleared)
        // 设备登记：每个条目只由那台设备自己写，key != myId 时以云端/对方为准，本机的保留
        var devs = remote.devices
        for ((k, v) in local.devices) {
            if (k == myId || devs[k] == null) devs = devs + (k to v)
        }
        out = out.copy(devices = devs)
        // 管理指令：按 id 并集，done 取并集（谁执行了就记谁），按创建时间排序
        val byId = LinkedHashMap<String, SyncCommand>()
        for (c in local.commands) byId[c.id] = c
        for (c in remote.commands) {
            val e = byId[c.id]
            byId[c.id] = if (e == null) c else e.copy(done = (e.done + c.done).distinct().sorted())
        }
        out = out.copy(commands = byId.values.sortedBy { it.createdAt })
        return out to false
    }

    private fun authIsLocal(l: Child, r: Child): Boolean {
        val lt = l.updatedAt ?: l.createdAt.atStartOfDay().minusYears(50)
        val rt = r.updatedAt ?: r.createdAt.atStartOfDay().minusYears(50)
        return lt >= rt
    }

    private fun mergeChild(l: Child, r: Child, tom: Set<String> = emptySet()): Child {
        val auth = if (authIsLocal(l, r)) l else r
        val other = if (auth === l) r else l
        // 合并前先按墓碑过滤，删除过的条目不会从另一端/云端旧快照里复活
        return auth.copy(
            records = mergeRecords(auth.records.filter { "rec:${it.id}" !in tom }, other.records.filter { "rec:${it.id}" !in tom }),
            feeds = mergeById(auth.feeds.filter { "feed:${it.id}" !in tom }, other.feeds.filter { "feed:${it.id}" !in tom }),
            sizes = dedupeSizes(mergeById(auth.sizes.filter { "size:${it.id}" !in tom }, other.sizes.filter { "size:${it.id}" !in tom })),
            todos = mergeById(auth.todos.filter { "todo:${it.id}" !in tom }, other.todos.filter { "todo:${it.id}" !in tom }),
            shots = mergeMaps(auth.shots, other.shots).filterKeys { "shot:$it" !in tom },
            // 脱落 / 龋齿按牙位并集，但已写删除墓碑的牙位不再从另一端/云端旧快照复活
            teethFallen = mergeTeeth(auth, other, tom, l.id),
            teethDecay = mergeTeethDecay(auth, other, tom, l.id),
        )
    }

    /** 生长记录按日期并集；同一天的字段互补（权威端优先，空位用另一端补） */
    private fun mergeRecords(a: List<GrowthRecord>, b: List<GrowthRecord>): List<GrowthRecord> {
        val byDate = a.associateBy { it.date }.toMutableMap()
        for (r in b) {
            val base = byDate[r.date]
            byDate[r.date] = when {
                base == null -> r
                base === r -> base
                else -> base.copy(
                    height = base.height ?: r.height,
                    weight = base.weight ?: r.weight,
                    footLength = base.footLength ?: r.footLength,
                    headCirc = base.headCirc ?: r.headCirc,
                    note = base.note.ifEmpty { r.note },
                )
            }
        }
        return byDate.values.sortedBy { it.date }
    }

    private inline fun <reified T> mergeById(a: List<T>, b: List<T>): List<T> {
        // 元素带 id 属性：按 id 并集，重复 id 保留权威端（a）的内容
        return if (b.isEmpty()) a else a + b.filter { o -> a.none { anyId(it) == anyId(o) } }
    }

    /**
     * 尺码去重（按天归并）：同一天只保留一条。
     * 老版本每次保存都追加，同一天能堆出好几条（有的只有腰围、有的最全），
     * 两端「取最新一条」时各挑到不同那条，看起来就像同步失败。
     * 现在以「字段最全」的那条为底，用同一天其它条补齐空缺，冲突时以最全的为准。
     */
    private fun dedupeSizes(list: List<SizeRecord>): List<SizeRecord> =
        list.filter { it.hasContent }
            .groupBy { it.dayKey }
            .values
            .map { group ->
                val base = group.maxWith(compareBy({ it.filledCount }, { it.id }))
                group.fold(base) { acc, s -> acc.fillMissingFrom(s) }
            }
            .sortedBy { it.date }

    private fun anyId(x: Any?): String? = when (x) {
        is com.zsonit.mengbao.model.FeedLog -> x.id
        is com.zsonit.mengbao.model.SizeRecord -> x.id
        is com.zsonit.mengbao.model.TodoItem -> x.id
        else -> null
    }

    private fun <K, V> mergeMaps(a: Map<K, V>, b: Map<K, V>): Map<K, V> {
        val out = a.toMutableMap()
        b.forEach { (k, v) -> if (!out.containsKey(k)) out[k] = v }
        return out
    }

    private fun mergeTeeth(a: Child, b: Child, tom: Set<String> = emptySet(), childId: String = ""): Map<Int, LocalDate>? {
        val am = a.teethFallen?.filterKeys { "toothFallen:$childId:$it" !in tom }
        val bm = b.teethFallen?.filterKeys { "toothFallen:$childId:$it" !in tom }
        if (am == null) return bm
        if (bm == null) return am
        val out = am.toMutableMap()
        bm.forEach { (k, v) -> if (!out.containsKey(k)) out[k] = v }
        return out.ifEmpty { null }
    }

    /** 龋齿记录同样按牙位并集；已写删除墓碑的牙位不会复活 */
    private fun mergeTeethDecay(a: Child, b: Child, tom: Set<String> = emptySet(), childId: String = ""): Map<Int, ToothDecay>? {
        val am = a.teethDecay?.filterKeys { "toothDecay:$childId:$it" !in tom }
        val bm = b.teethDecay?.filterKeys { "toothDecay:$childId:$it" !in tom }
        if (am == null) return bm
        if (bm == null) return am
        val out = am.toMutableMap()
        bm.forEach { (k, v) -> if (!out.containsKey(k)) out[k] = v }
        return out.ifEmpty { null }
    }

    // MARK: 网络与快照

    private class RemoteSnapshot(val state: AppState, val updatedBy: String)

    /** 查码是否已被占用；null = 网络失败 */
    private fun codeExists(code: String): Boolean? {
        val (body, status) = http("GET", "$REST?code=eq.$code&select=code&limit=1", null)
        if (status !in 200..299 || body == null) return null
        return JSONArray(body).length() > 0
    }

    /** 本机配对盐；没有则生成并保存 */
    private fun localSalt(): String {
        val p = prefs()
        val existing = p?.getString(KEY_SALT, null)
        if (existing != null) return existing
        val salt = SyncCrypto.newSalt()
        p?.edit()?.putString(KEY_SALT, salt)?.apply()
        return salt
    }

    /** 采用云端的盐（对方先创建配对时，两端必须用同一个盐才能互相解密） */
    private fun adoptSalt(remoteSalt: String) {
        val p = prefs() ?: return
        if (p.getString(KEY_SALT, null) != remoteSalt) {
            p.edit()?.putString(KEY_SALT, remoteSalt)?.apply()
        }
    }

    private fun fetchRemote(code: String): RemoteSnapshot? {
        val (body, _) = http("GET", "$REST?code=eq.$code&select=payload,updated_by,rev&limit=1", null)
        if (body == null) return null
        val arr = JSONArray(body)
        if (arr.length() == 0) return RemoteSnapshot(AppState(), EMPTY)
        val row = arr.optJSONObject(0) ?: return null
        setRev(row.optLong("rev", 0L))
        val payload = row.optJSONObject("payload") ?: return null

        // 新格式：端到端加密信封 —— 先采用云端盐，再用它解
        if (payload.has("ct")) {
            payload.optString("salt").takeIf { it.isNotEmpty() }?.let { adoptSalt(it) }
            val plain = SyncCrypto.decrypt(code, payload)
            if (plain == null) {
                // 解不开：配对码/盐对不上。返回标记让调用方跳过本轮，绝不能用本机数据覆盖云端
                AppLog.w("Sync", "云端密文无法解密（密钥不一致），本轮跳过，不覆盖云端")
                return RemoteSnapshot(AppState(), UNDECRYPTABLE)
            }
            return RemoteSnapshot(JsonCodec.decode(plain), row.optString("updated_by"))
        }

        // 旧格式兼容（2.5.1 及以前）：包裹结构 {v,device,ts,data} 或直接就是互通 JSON
        val data = payload.optJSONObject("data") ?: payload
        AppLog.i("Sync", "检测到旧版明文数据，本次同步后自动改成密文")
        return RemoteSnapshot(JsonCodec.decode(data.toString()), row.optString("updated_by"))
    }

    /** 推送：payload 列存加密信封，updated_by 记录来源设备，rev 供对端轻度轮询发现变化 */
    private fun upsert(code: String, state: AppState): SyncResult {
        val envelope = SyncCrypto.encrypt(code, JsonCodec.encode(state), localSalt())
            ?: return SyncResult(false, "本机加密失败")
        val rev = System.currentTimeMillis()
        val body = JSONObject()
            .put("code", code)
            .put("payload", envelope)
            .put("updated_by", deviceId())
            .put("rev", rev)
            .toString()
        val (errBody, status) = http(
            "POST",
            "$REST?on_conflict=code",
            body,
            extraHeaders = mapOf("Prefer" to "resolution=merge-duplicates"),
        ) ?: return SyncResult(false, "网络不可用")
        if (status in 200..299) {
            setRev(rev)
            return SyncResult(true, "OK")
        }
        val detail = errBody?.let {
            runCatching { JSONObject(it).optString("message") }.getOrNull()
        }
        return SyncResult(false, "HTTP $status${detail?.let { "：${it.take(80)}" } ?: ""}")
    }

    /** 返回 (响应体, HTTP 状态码)；网络异常返回 (null, 0) */
    private fun http(
        method: String,
        url: String,
        body: String?,
        extraHeaders: Map<String, String> = emptyMap(),
    ): Pair<String?, Int> {
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 15000
                readTimeout = 20000
                setRequestProperty("x-wb-webapp-access-key", PUBLISHABLE_KEY)
                setRequestProperty("Content-Type", "application/json")
                extraHeaders.forEach { (k, v) -> setRequestProperty(k, v) }
                if (body != null) doOutput = true
            }
            body?.let { text -> conn.outputStream.use { it.write(text.toByteArray(Charsets.UTF_8)) } }
            val status = conn.responseCode
            val stream = if (status in 200..299) conn.inputStream else conn.errorStream
            val text = stream?.use { it.readBytes().toString(Charsets.UTF_8) }
            text to status
        } catch (e: Exception) {
            AppLog.w("Sync", "网络请求失败：$method $e")
            null to 0
        } finally {
            conn?.disconnect()
        }
    }
}

data class SyncResult(val ok: Boolean, val message: String)
